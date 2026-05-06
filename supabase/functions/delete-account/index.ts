import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

async function deleteWhereUserId(
  adminClient: any,
  table: string,
  column: string,
  userId: string,
) {
  try {
    const { error } = await adminClient.from(table).delete().eq(column, userId);
    if (error != null) {
      const message = error.message.toLowerCase();
      if (
        message.includes("relation") ||
        message.includes("does not exist") ||
        message.includes("schema cache")
      ) {
        return;
      }
      throw error;
    }
  } catch (error) {
    const message = error instanceof Error ? error.message.toLowerCase() : "";
    if (
      message.includes("relation") ||
      message.includes("does not exist") ||
      message.includes("schema cache")
    ) {
      return;
    }
    throw error;
  }
}

async function getRemainingPlayerId(
  adminClient: any,
  roomId: string,
) {
  const { data, error } = await adminClient
    .from("multiplayer_room_players")
    .select("user_id, joined_at")
    .eq("room_id", roomId)
    .order("joined_at", { ascending: true })
    .limit(1);

  if (error != null) {
    throw error;
  }

  const rows = (data ?? []) as Array<{ user_id?: string }>;
  return rows[0]?.user_id ?? null;
}

async function cleanupRoomMemberships(
  adminClient: any,
  userId: string,
) {
  const roomIds = new Set<string>();

  const { data: joinedRooms, error: joinedRoomsError } = await adminClient
    .from("multiplayer_room_players")
    .select("room_id")
    .eq("user_id", userId);
  if (joinedRoomsError != null) {
    throw joinedRoomsError;
  }
  for (const row of (joinedRooms ?? []) as Array<{ room_id?: string }>) {
    if (typeof row.room_id == "string" && row.room_id.length > 0) {
      roomIds.add(row.room_id);
    }
  }

  const { data: hostedRooms, error: hostedRoomsError } = await adminClient
    .from("multiplayer_rooms")
    .select("id")
    .eq("host_user_id", userId);
  if (hostedRoomsError != null) {
    throw hostedRoomsError;
  }
  for (const row of (hostedRooms ?? []) as Array<{ id?: string }>) {
    if (typeof row.id == "string" && row.id.length > 0) {
      roomIds.add(row.id);
    }
  }

  await deleteWhereUserId(
    adminClient,
    "multiplayer_game_states",
    "user_id",
    userId,
  );
  await deleteWhereUserId(
    adminClient,
    "multiplayer_room_players",
    "user_id",
    userId,
  );

  for (const roomId of roomIds) {
    const { data: room, error: roomError } = await adminClient
      .from("multiplayer_rooms")
      .select("id, host_user_id, status")
      .eq("id", roomId)
      .maybeSingle();
    if (roomError != null) {
      throw roomError;
    }
    if (room == null) continue;

    const nextHostUserId = await getRemainingPlayerId(adminClient, roomId);
    if (nextHostUserId == null) {
      const { error: deleteRoomError } = await adminClient
        .from("multiplayer_rooms")
        .delete()
        .eq("id", roomId);
      if (deleteRoomError != null) {
        throw deleteRoomError;
      }
      continue;
    }

    const patch: Record<string, unknown> = {};
    const currentRoom = room as { host_user_id?: string; status?: string };

    if (currentRoom.host_user_id === userId) {
      patch.host_user_id = nextHostUserId;
    }
    if (currentRoom.status === "playing") {
      patch.status = "finished";
    }

    if (Object.keys(patch).length == 0) continue;

    const { error: updateRoomError } = await adminClient
      .from("multiplayer_rooms")
      .update(patch as Record<string, unknown>)
      .eq("id", roomId);
    if (updateRoomError != null) {
      throw updateRoomError;
    }
  }
}

async function cleanupUserData(
  adminClient: any,
  userId: string,
) {
  await cleanupRoomMemberships(adminClient, userId);
  await deleteWhereUserId(
    adminClient,
    "multiplayer_ranked_matchmaking_queue",
    "user_id",
    userId,
  );
  await deleteWhereUserId(adminClient, "user_shop_data", "user_id", userId);
  await deleteWhereUserId(
    adminClient,
    "user_store_purchases",
    "user_id",
    userId,
  );
  await deleteWhereUserId(adminClient, "scores", "user_id", userId);
  await deleteWhereUserId(adminClient, "profiles", "id", userId);
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

    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    await cleanupUserData(adminClient, user.id);

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(
      user.id,
    );

    if (deleteError != null) {
      return Response.json(
        { error: deleteError.message },
        { status: 500, headers: corsHeaders },
      );
    }

    return Response.json(
      { success: true, user_id: user.id },
      { headers: corsHeaders },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    return Response.json(
      { error: message },
      { status: 500, headers: corsHeaders },
    );
  }
});
