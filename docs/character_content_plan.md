# Character Content Plan

## 목적

현재 프로젝트는 `블록 모양`과 `색상` 중심으로 플레이 감각이 잡혀 있다.  
다음 단계에서는 이 구조를 완전히 버리기보다, 기존 판정과 배치 로직은 유지하고 `캐릭터 테마`를 입히는 방식이 가장 안전하다.

핵심은 아래 2가지를 동시에 만족하는 것이다.

1. 보드에서는 한눈에 배치 형태가 읽혀야 한다.
2. 상점, 프로필, 매치 화면에서는 캐릭터 수집 욕구가 생겨야 한다.

## 이 프로젝트에서 추천하는 방향

### 1. 블록 자체를 없애기보다 `캐릭터 편성체`로 바꾸기

현재 게임은 실제로는 `여러 칸을 차지하는 도형`을 드래그해서 놓는 구조다.  
그래서 클래시 로얄처럼 완전한 1유닛 배치 게임으로 바꾸기보다는, 아래처럼 해석하는 편이 맞다.

- 하나의 블록 = 하나의 캐릭터 팀 또는 소환 편성
- 블록의 각 칸 = 캐릭터가 점유하는 영역 또는 부대 칸
- 중앙 칸 또는 대표 칸 = 메인 캐릭터 얼굴/심볼
- 나머지 칸 = 보조 파츠, 오라, 깃발, 소환 흔적

이 방식이면 현재 `shape` 로직을 그대로 유지하면서도 시각적으로는 "캐릭터를 놓는 느낌"을 만들 수 있다.

### 2. 보드 위 캐릭터는 `풀바디`보다 `토큰형`이 낫다

지금 보드는 9x9 그리드라서 칸이 크지 않다.  
각 칸에 전신 캐릭터를 넣으면 읽기성이 바로 무너질 가능성이 높다.

추천 표현 방식:

- 보드 셀: 원형/사각형 토큰 + 캐릭터 얼굴 + 소속 색상 테두리
- 드래그 프리뷰: 캐릭터가 포함된 3x3 편성 프리뷰
- 프로필/상점: 반신 또는 얼굴 아이콘
- 결과 화면/상세 팝업: 전신 일러스트 가능

즉, `보드용`, `상점용`, `프로필용` 자산을 분리해야 한다.

## 꼭 필요한 콘텐츠 분류

### 1. 캐릭터 자산

최소 단위는 캐릭터 1종당 아래 구성이 필요하다.

- 대표 얼굴 아이콘
- 보드 셀용 토큰 이미지
- 드래그 프리뷰용 일러스트 또는 배치판
- 승리/패배/대기 화면용 반신 이미지
- 잠금 상태 썸네일

추가로 있으면 좋은 것:

- 감정표현 2~4종
- 등장 이펙트
- 희귀도별 프레임

### 2. UI 아이콘

현재는 `IconData` 기반 머티리얼 아이콘이 많다.  
캐릭터 테마를 강화하려면 일부는 커스텀 아이콘으로 바꾸는 게 좋다.

필요한 아이콘 묶음:

- 통화 아이콘: 코인, 티켓, 보석
- 메뉴 아이콘: 상점, 랭크전, 친구, 설정
- 상태 아이콘: 승리, 패배, 턴, 타이머, 연결 상태
- 상점 태그 아이콘: 신규, 추천, 한정, 잠금
- 감정/채팅 아이콘: 인사, 도발, 칭찬, 아쉬움

### 3. 배치/전투 보조 자산

- 드롭 가능 셀 하이라이트
- 캐릭터 소환 그림자
- 점유 완료 애니메이션
- 점수 획득 플로팅 효과
- 콤보/연속 배치 배지

### 4. 상점용 자산

현재 상점은 `아이콘`, `컬러`, `패턴` 탭 기준이다.  
캐릭터 중심으로 확장하면 아래 구성이 자연스럽다.

- 캐릭터
- 초상 아이콘
- 진영/테두리 스킨
- 배치 이펙트
- 감정표현

## 현재 코드 기준으로 필요한 구조 변경

### 1. 상점 데이터 구조 확장

현재 [lib/services/shop_service.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/services/shop_service.dart)는 `IconData`와 `Color` 중심이다.  
캐릭터 기반으로 가려면 `asset path`를 저장하는 구조가 필요하다.

추천 필드:

- `id`
- `name`
- `rarity`
- `price`
- `portraitAsset`
- `boardTokenAsset`
- `previewAsset`
- `lockedAsset`
- `themeColor`
- `emoteAssetIds`

### 2. 블록 렌더링 구조 교체

현재 [lib/tetris.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/tetris.dart)는 단색 사각형만 그린다.  
여기를 바꿔야 캐릭터 느낌이 제대로 난다.

추천 방식:

- 셀 배경은 유지
- 셀 내부에 토큰 이미지 렌더
- 대표 셀에는 얼굴이나 엠블럼 강조
- 소유자 색상은 이미지 위가 아니라 `테두리/바닥광`으로 표시

이렇게 해야 캐릭터 이미지를 덮어버리지 않으면서도 내 것/상대 것 구분이 된다.

### 3. 보드 셀 상태 표현 분리

현재 [lib/screens/multiplayer_game/multiplayer_board.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/screens/multiplayer_game/multiplayer_board.dart)는 셀을 거의 `색상`으로만 표현한다.  
캐릭터 기반으로 바꾸면 표현 레이어를 나눠야 한다.

추천 레이어:

- 바닥 레이어: 빈칸, 점유칸, 호버칸
- 소속 레이어: 내 팀/상대 팀 오라 또는 링
- 콘텐츠 레이어: 캐릭터 토큰
- 상태 레이어: 방금 배치, 제거, 콤보 효과

### 4. 드래그 프리뷰 교체

현재 [lib/screens/multiplayer_game/multiplayer_draggable_block.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/screens/multiplayer_game/multiplayer_draggable_block.dart)는 작은 컬러 블록 미리보기다.  
여기는 `캐릭터 편성 카드`처럼 보여야 한다.

추천 표현:

- 프리뷰 슬롯 안에 캐릭터 이름
- 중심 캐릭터 얼굴 1개
- 점유 형태를 보여주는 보조 셀
- 선택된 스킨 색상 테두리

## 아트 방향 추천

이 프로젝트에는 아래 방향이 가장 맞다.

### 추천: `캐주얼 전략 보드 + SD 캐릭터`

이유:

- 작은 셀에서도 얼굴과 실루엣이 잘 읽힌다.
- 상점/프로필/매치 UI와 잘 어울린다.
- 제작 난이도가 풀 일러스트보다 낮다.
- 이후 감정표현, 스킨, 색상 변형이 쉽다.

피해야 할 방향:

- 너무 디테일한 전신 일러스트
- 색이 너무 많은 복잡한 디자인
- 셀 내부를 가득 채우는 실사풍 그림

## 최소 MVP 기준으로 필요한 것

처음부터 많이 만들 필요는 없다.  
아래 정도면 캐릭터 시스템 테스트가 가능하다.

### 캐릭터

- 기본 캐릭터 4종
- 각 캐릭터별 얼굴 아이콘 1개
- 보드 토큰 1개
- 프리뷰용 배치 이미지 1개

### UI 아이콘

- 코인
- 상점
- 랭크
- 멀티
- 설정
- 잠금
- 추천
- 신규

### 효과

- 배치 성공 이펙트 1종
- 승리 강조 배지 1종
- 선택 강조 링 1종

## 우선순위

### 1차

- 캐릭터 테마 정의
- 캐릭터 4종 컨셉 확정
- 보드용 토큰 스타일 확정
- 상점 데이터 모델을 에셋 기반으로 변경

### 2차

- 드래그 프리뷰를 캐릭터형으로 변경
- 프로필 아이콘을 커스텀 이미지 기반으로 변경
- 상점 탭을 `캐릭터 / 초상 / 이펙트` 구조로 개편

### 3차

- 감정표현 추가
- 희귀도/등급 프레임 추가
- 승패 화면 전용 캐릭터 아트 추가

## 실무적으로 먼저 정해야 하는 것

캐릭터 작업 들어가기 전에 아래를 먼저 정해야 한다.

1. 캐릭터가 `한 칸 유닛`인지 `여러 칸 편성체`인지
2. 보드에서 보여줄 게 `얼굴`, `반신`, `심볼` 중 무엇인지
3. 상점에서 팔 단위가 `캐릭터`, `아이콘`, `스킨`, `이펙트` 중 무엇인지
4. 캐릭터가 게임 성능에 영향 없는 순수 스킨인지, 아니면 타입별 개성이 있는지

지금 프로젝트 상태에서는 `성능 차이 없는 스킨형 캐릭터`부터 시작하는 게 가장 안전하다.

## 결론

이 프로젝트에서는 `블록을 없애고 캐릭터를 넣는 것`보다,  
`기존 블록 구조를 캐릭터 편성체로 해석해서 시각만 캐릭터화`하는 방향이 가장 적합하다.

가장 먼저 필요한 것은 아래 3가지다.

- 보드용 캐릭터 토큰 스타일 정의
- 상점/프로필용 캐릭터 아이콘 세트 정의
- 에셋 기반 데이터 구조로 전환

이 3개가 정리되면 이후에는 그래픽 작업과 Flutter 렌더링 작업을 병행할 수 있다.

## 스타터 캐릭터 4종 제안

처음에는 서로 실루엣, 색, 역할 감정이 확실히 다른 4종이 좋다.  
그래야 작은 아이콘으로도 구분되고 상점에서 보기에도 덜 밋밋하다.

### 1. 플레어 대장

- 키워드: 불, 돌격, 열정
- 메인 컬러: 코랄 레드, 주황
- 보드 인상: 화염 머리, 삼각형 눈썹, 불꽃 링
- 성격 톤: 자신감, 공격적, 빠른 템포
- 어울리는 희귀도: 기본 또는 레어

추천 자산 방향:

- 얼굴 아이콘은 웃는 표정보다 `결의 있는 표정`
- 보드 토큰은 불꽃 모양 테두리
- 배치 이펙트는 짧은 오렌지 섬광

### 2. 미스트 마법사

- 키워드: 안개, 지능, 제어
- 메인 컬러: 민트, 하늘, 청록
- 보드 인상: 둥근 모자, 별 장식, 부드러운 오라
- 성격 톤: 차분함, 계산적, 신비감
- 어울리는 희귀도: 레어

추천 자산 방향:

- 얼굴 아이콘은 눈이 강조된 형태
- 보드 토큰은 원형 글리프 느낌
- 배치 이펙트는 옅은 안개 퍼짐

### 3. 볼트 엔지니어

- 키워드: 번개, 기계, 장치
- 메인 컬러: 옐로, 네이비, 스틸 그레이
- 보드 인상: 고글, 번개 안테나, 육각형 프레임
- 성격 톤: 빠름, 장난기, 기술자 감성
- 어울리는 희귀도: 레어

추천 자산 방향:

- 얼굴 아이콘은 고글과 번개 문양을 고정 요소로 사용
- 보드 토큰은 각진 프레임
- 배치 이펙트는 짧은 전기 스파크

### 4. 블룸 가디언

- 키워드: 숲, 회복, 수호
- 메인 컬러: 그린, 크림, 골드
- 보드 인상: 잎 장식, 둥근 실루엣, 자연 오라
- 성격 톤: 안정감, 친절함, 든든함
- 어울리는 희귀도: 기본 또는 레어

추천 자산 방향:

- 얼굴 아이콘은 부드러운 미소
- 보드 토큰은 잎사귀 패턴 외곽선
- 배치 이펙트는 작은 잎 파편

## 캐릭터별 배치 해석 예시

현재 도형 배치를 캐릭터적으로 보이게 하려면, 각 캐릭터가 모양을 어떻게 점유하는지 설명이 붙어야 한다.

예시:

- `O`형 배치: 방진형 소환, 수비형 진영
- `T`형 배치: 본체 + 좌우 확장, 지휘형 캐릭터
- `L`형 배치: 전진형 돌파, 돌격대 느낌
- `S/Z`형 배치: 기동형, 트릭키한 이동 느낌
- `1칸` 배치: 핵심 코어, 리더 마커

즉, 캐릭터가 모양을 바꾸는 게 아니라 `모양에 서사가 붙는 방식`으로 가면 현재 시스템과 가장 잘 맞는다.

## 아이콘 세트 제안

### 1. 프로필 아이콘

프로필 아이콘은 캐릭터 얼굴을 단순 크롭한 것보다 `전용 아이콘 버전`이 필요하다.

권장 규칙:

- 정면 또는 3/4 시점만 사용
- 배경은 단색 또는 약한 그라디언트
- 턱선 아래는 잘라서 원형 크롭에 맞춤
- 외곽선 1겹 + 희귀도 링 1겹

### 2. 게임 UI 아이콘

게임 전용 아이콘은 캐릭터풍이어도 기능이 바로 읽혀야 한다.

추천 세트:

- `coin`: 둥근 금화
- `gem`: 육각 보석
- `rank`: 왕관 또는 메달
- `shop`: 가방 또는 진열함
- `multiplayer`: 교차 깃발
- `timer`: 원형 시계
- `turn`: 깃발 또는 포인터
- `win`: 왕관 별
- `lose`: 깨진 방패
- `lock`: 자물쇠
- `new`: 반짝이 배지
- `hot`: 불꽃 배지
- `recommended`: 체크 별표

### 3. 감정표현 아이콘

처음부터 많을 필요는 없다.

MVP 추천:

- 인사
- 좋아요
- 아쉬움
- 도발

## 에셋 폴더 구조 제안

현재는 [pubspec.yaml](/Users/kik/Documents/ma-neoreo/link_your_area/pubspec.yaml) 에 `assets/icons/`만 등록돼 있다.  
캐릭터 작업을 시작하면 아래 구조로 정리하는 게 무난하다.

```text
assets/
  icons/
    app/
    ui/
    currency/
    status/
    emotes/
  characters/
    flare_captain/
      profile/
      board/
      preview/
      splash/
      emotes/
    mist_mage/
      profile/
      board/
      preview/
      splash/
      emotes/
    bolt_engineer/
      profile/
      board/
      preview/
      splash/
      emotes/
    bloom_guardian/
      profile/
      board/
      preview/
      splash/
      emotes/
  effects/
    placement/
    combo/
    victory/
```

## 파일 네이밍 규칙

폴더 구조보다 파일명이 더 중요하다.  
처음부터 규칙이 없으면 상점 연결할 때 바로 꼬인다.

권장 규칙:

- 전부 소문자
- 공백 금지
- 단어는 `_` 로 구분
- 캐릭터 id를 파일명 앞에 고정

예시:

- `flare_captain_profile_face.png`
- `flare_captain_board_token.png`
- `flare_captain_preview_card.png`
- `flare_captain_splash_win.png`
- `flare_captain_emote_wave.png`
- `icon_coin_gold.png`
- `icon_rank_crown.png`
- `effect_place_flash_orange.png`

## 캐릭터 1종당 실제 필요 파일

MVP 기준으로 캐릭터 하나당 아래 정도면 된다.

```text
profile/
  character_profile_face.png
board/
  character_board_token.png
  character_board_token_locked.png
preview/
  character_preview_card.png
splash/
  character_splash_idle.png
emotes/
  character_emote_wave.png
  character_emote_taunt.png
```

최소 시작 버전은 더 줄여도 된다.

- `profile_face`
- `board_token`
- `preview_card`

이 3개만 있어도 상점, 프로필, 드래그 프리뷰까지는 연결 가능하다.

## 코드 연결 기준 데이터 모델 예시

현재 [lib/services/shop_service.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/services/shop_service.dart)는 `IconData` 위주라서 이후에는 이런 식의 모델이 필요하다.

```dart
class CharacterItem {
  final String id;
  final String name;
  final String rarity;
  final int price;
  final Color themeColor;
  final String profileFaceAsset;
  final String boardTokenAsset;
  final String previewCardAsset;
  final String splashIdleAsset;
  final List<String> emoteAssets;

  const CharacterItem({
    required this.id,
    required this.name,
    required this.rarity,
    required this.price,
    required this.themeColor,
    required this.profileFaceAsset,
    required this.boardTokenAsset,
    required this.previewCardAsset,
    required this.splashIdleAsset,
    required this.emoteAssets,
  });
}
```

## 스타터 캐릭터 데이터 예시

```dart
const starterCharacters = [
  CharacterItem(
    id: 'flare_captain',
    name: '플레어 대장',
    rarity: 'common',
    price: 0,
    themeColor: Color(0xFFE85D75),
    profileFaceAsset:
        'assets/characters/flare_captain/profile/flare_captain_profile_face.png',
    boardTokenAsset:
        'assets/characters/flare_captain/board/flare_captain_board_token.png',
    previewCardAsset:
        'assets/characters/flare_captain/preview/flare_captain_preview_card.png',
    splashIdleAsset:
        'assets/characters/flare_captain/splash/flare_captain_splash_idle.png',
    emoteAssets: [
      'assets/characters/flare_captain/emotes/flare_captain_emote_wave.png',
    ],
  ),
];
```

## 적용 순서 제안

실제 작업 순서는 아래가 가장 덜 꼬인다.

1. 캐릭터 4종 id와 이름 확정
2. 프로필 얼굴 아이콘 4개 먼저 제작
3. 보드 토큰 4개 제작
4. 프리뷰 카드 4개 제작
5. `ShopService`를 에셋 기반 모델로 확장
6. 프로필/상점에 이미지 연결
7. 보드와 드래그 프리뷰에 토큰 렌더링 연결

## 지금 바로 추천하는 결정안

빠르게 진행하려면 아래처럼 고정하고 시작하는 게 좋다.

- 캐릭터 수: 4종
- 희귀도: `common`, `rare` 두 단계만 먼저
- 프로필 아이콘: 원형 얼굴형
- 보드 표현: 원형 토큰 + 팀 컬러 링
- 프리뷰 표현: 캐릭터 얼굴 + 도형 실루엣
- 상점 탭: `캐릭터`, `아이콘`, `이펙트`

이렇게 시작하면 지금 구조를 크게 엎지 않고도 캐릭터 수집형 느낌을 만들 수 있다.
