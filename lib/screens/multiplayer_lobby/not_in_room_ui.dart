import 'package:link_your_area/services/multiplayer_service.dart';
import 'package:link_your_area/theme/app_design_system.dart';
import 'package:link_your_area/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';


class NotInRoomUi extends StatefulWidget {
  final bool isBusy;

  const NotInRoomUi({
    super.key,
    required this.isBusy,
  });

  @override
  State<NotInRoomUi> createState() => _NotInRoomUiState();
}

class _NotInRoomUiState extends State<NotInRoomUi> {
  final TextEditingController _roomTitleController = TextEditingController();

  MultiplayerService get _service => Get.find<MultiplayerService>();

  @override
  void dispose() {
    _roomTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildFriendlyUi();
  }

  Widget _buildFriendlyUi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '참여 가능한 방',
              style: AppTypography.label.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            GestureDetector(
              onTap: _service.fetchAvailableRooms,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _service.fetchAvailableRooms,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: _buildAvailableRoomsList(),
          ),
        ),
        const SizedBox(height: 20),
        _buildCreateRoomRow(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCreateRoomRow() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.borderSoft.withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: _roomTitleController,
        style: AppTypography.body.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: '친선전 방 제목을 입력하세요',
          hintStyle: AppTypography.body.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.edit_outlined,
            size: 20,
            color: AppColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
            child: FilledButton(
              onPressed: widget.isBusy
                  ? null
                  : () => _service.createRoom(
                        roomTitle: _roomTitleController.text,
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ).copyWith(
                shadowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.2)),
                elevation: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.pressed) ? 2 : 4),
              ),
              child: widget.isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : Text(
                      '생성',
                      style: AppTypography.label.copyWith(
                        fontSize: 14,
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) {
          if (!widget.isBusy) {
            _service.createRoom(roomTitle: _roomTitleController.text);
          }
        },
      ),
    );
  }

  Widget _buildAvailableRoomsList() {
    return Obx(() {
      final rooms = _service.availableRooms;
      final isFetching = _service.isFetchingRooms.value;

      if (isFetching && rooms.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        );
      }

      if (rooms.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.borderSoft.withValues(alpha: 0.8),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 40,
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '지금 들어갈 수 있는 방이 없습니다.\n직접 방을 만들거나 잠시 후 다시 확인해보세요.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          final hostName = room['host_nickname'] ?? '플레이어';
          final roomTitle = room['room_title']?.toString().trim();
          final roomId = room['id'] as String;

          return GestureDetector(
            onTap: _service.isBusy.value
                ? null
                : () => _service.joinRoomById(roomId),
            child: Container(
              margin: EdgeInsets.only(bottom: 14, top: index == 0 ? 6 : 0),
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: AppColors.borderSoft.withValues(alpha: 0.8),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomTitle != null && roomTitle.isNotEmpty
                              ? roomTitle
                              : '$hostName의 방',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            fontSize: 17,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                hostName,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.ink.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (room['host_grade_icon_path'] != null) ...[
                              const SizedBox(width: 4),
                              Image.asset(
                                room['host_grade_icon_path'] as String,
                                width: 18,
                                height: 18,
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              '· 대기 중',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '입장',
                      style: AppTypography.label.copyWith(
                        fontSize: 14,
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}
