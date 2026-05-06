# 코인 스토어 결제 흐름

코인 충전은 외부 결제 링크가 아니라 스토어 인앱결제로 처리한다.

- iOS: App Store 인앱구매
- Android: Google Play Billing

## 앱 흐름

1. 앱이 `in_app_purchase`로 스토어 상품 `500_coin`, `1200_coin`, `2500_coin`를 조회한다.
2. 사용자가 충전 버튼을 누르면 App Store 또는 Google Play 결제창을 연다.
3. 구매 결과는 `purchaseStream`으로 받는다.
4. 앱은 구매 영수증 데이터를 서버 함수 `claim-store-purchase`로 보낸다.
5. 서버가 영수증을 검증한 뒤 `shop_grant_store_purchase`를 `service_role`로 호출한다.
6. SQL 함수가 중복 적립을 막고 `user_shop_data.coins`에 코인을 적립한다.

## 서버에서 해야 할 일

`claim-store-purchase` 같은 Supabase Edge Function 또는 별도 서버가 필요하다.

- Apple 영수증 또는 App Store Server API 검증
- Google Play purchase token 검증
- 검증 성공 시 `shop_grant_store_purchase(...)` 호출

앱 클라이언트가 직접 코인을 적립하면 안 된다.

## 필요한 설정

- App Store Connect / Google Play Console 에 동일한 상품 ID 등록
  - `500_coin`
  - `1200_coin`
  - `2500_coin`
- 앱 환경변수
  - `STORE_PURCHASE_VERIFY_FUNCTION`
- Supabase SQL
  - `/Users/kik/Documents/ma-neoreo/link_your_area/supabase/shop_schema.sql`
  - `/Users/kik/Documents/ma-neoreo/link_your_area/supabase/shop_coin_payments.sql`

## 중요한 점

- 코인은 소모성 상품이므로 복원 대신 서버 적립 기록이 기준이 된다.
- 구매 완료 후에도 서버 검증이 끝나기 전까지는 코인을 지급하면 안 된다.
- 검증 서버는 구매 토큰 기준으로 중복 적립을 막아야 한다.
