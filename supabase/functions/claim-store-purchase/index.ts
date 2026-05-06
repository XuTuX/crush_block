import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const textEncoder = new TextEncoder();

type PurchaseRequest = {
  game_key?: string;
  product_id?: string;
  purchase_id?: string | null;
  transaction_date?: string | null;
  verification_data?: {
    source?: string;
    server_verification_data?: string;
    local_verification_data?: string;
  };
};

function base64UrlEncode(input: Uint8Array | string) {
  const bytes = typeof input === "string" ? textEncoder.encode(input) : input;
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function normalizePrivateKey(raw: string) {
  return raw.replace(/\\n/g, "\n");
}

function pemToArrayBuffer(pem: string) {
  const sanitized = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(sanitized);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function importPrivateKey(privateKey: string) {
  return await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(normalizePrivateKey(privateKey)),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}

async function createServiceAccountJwt(
  serviceAccountEmail: string,
  privateKey: string,
) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccountEmail,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;
  const key = await importPrivateKey(privateKey);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    textEncoder.encode(unsignedToken),
  );

  return `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;
}

async function getGoogleAccessToken() {
  const email = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL");
  const privateKey = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY");
  if (!email || !privateKey) {
    throw new Error("Missing Google Play service account credentials.");
  }

  const assertion = await createServiceAccountJwt(email, privateKey);
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  const payload = await response.json();
  if (!response.ok || typeof payload.access_token !== "string") {
    throw new Error(payload.error_description ?? "Failed to fetch Google access token.");
  }

  return payload.access_token as string;
}

function inferStore(source?: string) {
  const normalized = source?.toLowerCase() ?? "";
  if (
    normalized.includes("google") ||
    normalized.includes("play") ||
    normalized.includes("android")
  ) {
    return "google_play" as const;
  }
  if (
    normalized.includes("apple") ||
    normalized.includes("app_store") ||
    normalized.includes("ios")
  ) {
    return "app_store" as const;
  }
  throw new Error("Unable to determine store from verification data.");
}

function parseTimestamp(value?: string | null) {
  if (!value) return null;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

async function verifyGooglePlayPurchase(
  productId: string,
  purchaseToken: string,
) {
  const packageName = Deno.env.get("GOOGLE_PLAY_PACKAGE_NAME");
  if (!packageName) {
    throw new Error("Missing GOOGLE_PLAY_PACKAGE_NAME.");
  }

  const accessToken = await getGoogleAccessToken();
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(packageName)}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`,
    {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  );
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(payload.error?.message ?? "Google Play purchase verification failed.");
  }
  if (payload.purchaseState !== 0) {
    throw new Error("Google Play purchase is not completed.");
  }

  return {
    purchaseToken: String(payload.purchaseToken ?? purchaseToken),
    transactionDate: payload.purchaseTimeMillis
      ? new Date(Number(payload.purchaseTimeMillis)).toISOString()
      : null,
    rawPayload: payload,
  };
}

async function callAppleVerifyReceipt(
  endpoint: string,
  receiptData: string,
) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      "receipt-data": receiptData,
      "exclude-old-transactions": false,
    }),
  });

  const payload = await response.json();
  if (!response.ok) {
    throw new Error("Apple receipt verification request failed.");
  }
  return payload;
}

async function verifyApplePurchase(
  productId: string,
  purchaseId: string | null | undefined,
  receiptData: string,
) {
  let payload = await callAppleVerifyReceipt(
    "https://buy.itunes.apple.com/verifyReceipt",
    receiptData,
  );

  if (payload.status === 21007) {
    payload = await callAppleVerifyReceipt(
      "https://sandbox.itunes.apple.com/verifyReceipt",
      receiptData,
    );
  }

  if (payload.status !== 0) {
    throw new Error(`Apple receipt verification failed with status ${payload.status}.`);
  }

  const transactions = [
    ...(Array.isArray(payload.latest_receipt_info) ? payload.latest_receipt_info : []),
    ...(Array.isArray(payload.receipt?.in_app) ? payload.receipt.in_app : []),
  ].filter((entry) => entry?.product_id === productId);

  if (transactions.length === 0) {
    throw new Error("Apple receipt does not contain the requested product.");
  }

  const matchedTransaction = transactions.find((entry) =>
    purchaseId != null && entry?.transaction_id === purchaseId
  ) ?? transactions.sort((a, b) =>
    Number(b?.purchase_date_ms ?? 0) - Number(a?.purchase_date_ms ?? 0)
  )[0];

  const token =
    matchedTransaction?.transaction_id ??
    matchedTransaction?.original_transaction_id ??
    purchaseId;
  if (!token) {
    throw new Error("Apple receipt is missing a transaction identifier.");
  }

  const purchaseDateMs = matchedTransaction?.purchase_date_ms;
  return {
    purchaseToken: String(token),
    transactionDate: purchaseDateMs
      ? new Date(Number(purchaseDateMs)).toISOString()
      : null,
    rawPayload: matchedTransaction ?? payload,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization");

    if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
      return Response.json(
        { error: "Missing Supabase environment variables." },
        { status: 500, headers: corsHeaders },
      );
    }

    if (!authHeader) {
      return Response.json(
        { error: "Missing authorization header." },
        { status: 401, headers: corsHeaders },
      );
    }

    const body = await req.json() as PurchaseRequest;
    const productId = body.product_id?.trim();
    const gameKey = body.game_key?.trim() || "link_your_area";
    const verificationData = body.verification_data ?? {};

    if (!productId) {
      return Response.json(
        { error: "Missing product_id." },
        { status: 400, headers: corsHeaders },
      );
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const {
      data: { user },
      error: getUserError,
    } = await userClient.auth.getUser();

    if (getUserError != null || user == null) {
      return Response.json(
        { error: "Unable to verify current user." },
        { status: 401, headers: corsHeaders },
      );
    }

    const store = inferStore(verificationData.source);
    let verifiedPurchase: {
      purchaseToken: string;
      transactionDate: string | null;
      rawPayload: unknown;
    };

    if (store === "google_play") {
      const purchaseToken = verificationData.server_verification_data?.trim();
      if (!purchaseToken) {
        throw new Error("Missing Google Play purchase token.");
      }
      verifiedPurchase = await verifyGooglePlayPurchase(productId, purchaseToken);
    } else {
      const receiptData =
        verificationData.server_verification_data?.trim() ||
        verificationData.local_verification_data?.trim();
      if (!receiptData) {
        throw new Error("Missing App Store receipt data.");
      }
      verifiedPurchase = await verifyApplePurchase(
        productId,
        body.purchase_id,
        receiptData,
      );
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data, error } = await adminClient.rpc("shop_grant_store_purchase", {
      p_user_id: user.id,
      p_store: store,
      p_product_id: productId,
      p_purchase_token: verifiedPurchase.purchaseToken,
      p_purchase_id: body.purchase_id ?? null,
      p_transaction_date:
        verifiedPurchase.transactionDate ?? parseTimestamp(body.transaction_date),
      p_game_key: gameKey,
      p_raw_payload: {
        request: body,
        verified_purchase: verifiedPurchase.rawPayload,
      },
    });

    if (error != null) {
      throw error;
    }

    return Response.json(data, { headers: corsHeaders });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return Response.json(
      { error: message },
      { status: 500, headers: corsHeaders },
    );
  }
});
