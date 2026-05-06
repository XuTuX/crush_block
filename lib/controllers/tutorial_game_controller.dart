import 'package:get/get.dart';

class TutorialGameController extends GetxController {
  final step = 0.obs;

  final pages = const [
    (
      title: '블록 선택',
      body:
          '게임 시작 전에 I, O, T, L, J, S, Z 중 하나를 고릅니다. 선택한 블록만 게임 내내 사용할 수 있습니다.',
    ),
    (
      title: '턴 진행',
      body: '자기 턴에는 선택한 테트로미노를 빈 칸에 놓습니다. 벽, 기존 블록, 보드 밖으로는 놓을 수 없습니다.',
    ),
    (
      title: '폭발',
      body: '가로나 세로 방향에서 두 벽 사이가 빈칸 없이 모두 채워지면 사이의 블록이 전부 제거되고 추가 턴을 얻습니다.',
    ),
    (
      title: '승리 조건',
      body: '상대 턴이 되었을 때 상대가 자신의 블록을 놓을 수 있는 위치가 하나도 없으면 승리합니다.',
    ),
  ];

  bool get isLast => step.value >= pages.length - 1;

  void next() {
    if (!isLast) {
      step.value += 1;
    } else {
      Get.back(result: true);
    }
  }

  void previous() {
    if (step.value > 0) step.value -= 1;
  }
}
