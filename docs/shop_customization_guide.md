# 상점 아이템(캐릭터/아이콘) 교체 및 커스터마이징 가이드

상점에서 사용 중인 예시 캐릭터와 초상화를 실제 서비스에 사용할 자산으로 교체하는 단계별 가이드입니다.

---

## 1단계: 자산(Asset) 준비 및 배치

먼저 제작하신 이미지 파일들을 다음 폴더 규칙에 맞춰 프로젝트에 배치합니다.

*   **초상화(Portrait):** [assets/portraits/](file:///Users/nomang/Documents/ma_neoreo/crush_block/assets/portraits/)
    *   용도: 상점 리스트, 본인 프로필, 로그인 화면 등에 표시될 얼굴 이미지
    *   규격: **1:1(정사각형) 비율**, 배경 투명 PNG 권장
*   **게임 말(Token):** [assets/tokens/](file:///Users/nomang/Documents/ma_neoreo/crush_block/assets/tokens/)
    *   용도: 게임 보드 위에서 실제로 움직일 캐릭터 스킨
    *   규격: 배경 투명 PNG 권장
*   **기타 아이콘:** [assets/icons/](file:///Users/nomang/Documents/ma_neoreo/crush_block/assets/icons/)

> [!TIP]
> 파일명은 `knight_portrait.png`, `knight_token.png` 처럼 **ID_구분.png** 형식을 사용하면 관리하기가 매우 수월합니다.

---

## 2단계: Flutter 코드 수정

상점의 데이터 정의는 [lib/services/shop_service.dart](file:///Users/nomang/Documents/ma_neoreo/crush_block/lib/services/shop_service.dart) 파일에서 관리합니다.

### 1. 캐릭터 카탈로그 수정
`characterCatalog` 리스트를 본인의 아이템으로 교체하거나 추가합니다.

```dart
static const List<CharacterItem> characterCatalog = [
  CharacterItem(
    id: 'my_new_hero', // 고유 ID (중요: DB/SQL과 일치해야 함)
    name: '새로운 전사',
    rarity: CharacterRarity.rare,
    price: 500,
    themeColor: Color(0xFF...), // 캐릭터를 상징하는 색상 (Hex)
    portraitAsset: 'assets/portraits/my_hero_portrait.png',
    tokenAsset: 'assets/tokens/my_hero_token.png',
  ),
];
```

### 2. 초상화(Avatar) 카탈로그 수정
캐릭터 카탈로그와 별개로, 상점의 'Portrait' 탭에 표시될 내용을 `portraitCatalog`에서 수정합니다.

```dart
static const List<PortraitItem> portraitCatalog = [
  PortraitItem(
    id: 'my_new_hero_face',
    characterId: 'my_new_hero', // 연결된 캐릭터의 ID
    name: '새로운 전사 초상',
    price: 0, // 0이면 캐릭터 구매 시 자동 획득 등의 로직으로 사용 가능
    assetPath: 'assets/portraits/my_hero_portrait.png',
  ),
];
```

---

## 3단계: Supabase 데이터베이스 수정

클라이언트 코드만 수정하면 서버에서 소유권 확인이나 가격 계산 시 오류가 발생할 수 있습니다. [supabase/shop_character_portraits.sql](file:///Users/nomang/Documents/ma_neoreo/crush_block/supabase/shop_character_portraits.sql) 파일을 수정하여 새로운 ID를 등록해야 합니다.

### 1. 가격 정보 등록
`shop_character_price` 함수와 `shop_portrait_price` 함수의 `case` 문에 새 ID와 가격을 추가합니다.

```sql
-- 캐릭터 가격
create or replace function public.shop_character_price(p_item_id text)
returns int as $$
  select case p_item_id
    when 'my_new_hero' then 500
    -- ...
    else null
  end
$$ language sql immutable;
```

### 2. 가입 시 기본 캐릭터 설정
가입할 때 기본으로 제공할 캐릭터를 변경하려면 `user_shop_data` 테이블의 `owned_characters` 기본값(Default)을 수정하세요.

---

## 추천하는 진행 요령

1.  **하나씩 교체하기**: 한꺼번에 모든 예시를 지우기보다, `flare_captain` 같은 기존 예시 하나를 먼저 자신의 그림으로 교체하여 **실제 게임에서 잘 보이는지 확인**한 뒤 나머지를 작업하세요.
2.  **ID 일관성**: 코드(`dart`)와 데이터베이스(`sql`)에 들어가는 **ID 문자열이 완전히 똑같아야** 장착/구매 시 오류가 나지 않습니다.
3.  **임시 이미지 사용**: 최종 그림이 나오기 전까지는 `generate_image`를 통해 만든 임시 그림으로 먼저 구조를 잡아두셔도 좋습니다.

---
최종 업데이트: 2026-03-25
