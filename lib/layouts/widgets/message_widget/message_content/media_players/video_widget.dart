import 'package:dart_vlc/dart_vlc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:tuple/tuple.dart';
import 'package:universal_io/io.dart';
import 'package:universal_html/html.dart' as html;

import 'package:bluebubbles/helpers/constants.dart';
import 'package:bluebubbles/helpers/hex_color.dart';
import 'package:bluebubbles/helpers/navigator.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/layouts/image_viewer/attachmet_fullscreen_viewer.dart';
import 'package:bluebubbles/layouts/widgets/theme_switcher/theme_switcher.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum PlayerStatus { NONE, STOPPED, PAUSED, PLAYING, ENDED }

class VideoWidgetController extends GetxController with SingleGetTickerProviderMixin {
  bool navigated = false;
  bool isVisible = false;
  PlayerStatus status = PlayerStatus.NONE;
  bool hasListener = false;
  late final VideoPlayerController controller;
  late final Player desktopController;
  final RxBool showPlayPauseOverlay = true.obs;
  final RxBool muted = true.obs;
  final PlatformFile file;
  final Attachment attachment;
  final BuildContext context;

  VideoWidgetController({
    required this.file,
    required this.attachment,
    required this.context,
  });

  @override
  void onInit() {
    super.onInit();
    muted.value = SettingsManager().settings.startVideosMuted.value;
    Map<String, Tuple2<VideoPlayerController, Player>> controllers = CurrentChat.of(context)!.currentPlayingVideo;
    showPlayPauseOverlay.value = !controllers.containsKey(attachment.guid) ||
        (kIsDesktop
            ? !controllers[attachment.guid]!.item2.playback.isPlaying
            : !controllers[attachment.guid]!.item1.value.isPlaying);

    if (controllers.containsKey(attachment.guid)) {
      desktopController = controllers[attachment.guid]!.item2;
      controller = controllers[attachment.guid]!.item1;
    } else {
      initializeController();
    }
    createListener(controller, desktopController);
  }

  void initializeController() async {
    PlatformFile file2 = file;
    if (kIsWeb) {
      final blob = html.Blob([file2.bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      controller = VideoPlayerController.network(url);
    } else {
      dynamic file = File(file2.path);
      if (kIsDesktop) {
        desktopController = Player(id: file.hashCode)..open(Media.file(file));
      }
      controller = new VideoPlayerController.file(file);
    }
    await controller.initialize();
    CurrentChat.of(context)!.changeCurrentPlayingVideo({attachment.guid!: Tuple2(controller, desktopController)});
  }

  void createListener(VideoPlayerController controller, desktopPlayer) {
    if (hasListener) return;

    if (kIsDesktop) {
      desktopPlayer!.playbackStream.listen((PlaybackState state) {
        if (state.isCompleted) {
          desktopPlayer.pause();
          desktopPlayer.seek(Duration());
        }
      });
    } else {
      controller.addListener(() async {
        // Get the current status
        PlayerStatus currentStatus = await getControllerStatus(controller);

        // If the status hasn't changed, don't do anything
        if (currentStatus == status) return;
        this.status = currentStatus;

        // If the status is ended, restart
        if (this.status == PlayerStatus.ENDED) {
          showPlayPauseOverlay.value = true;
          await controller.pause();
          await controller.seekTo(Duration());
        }
      });
    }

    hasListener = true;
  }
}

class VideoWidget extends StatelessWidget {
  VideoWidget({
    Key? key,
    required this.file,
    required this.attachment,
  }) : super(key: key);
  final PlatformFile file;
  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VideoWidgetController>(
      global: false,
      init: VideoWidgetController(file: file, attachment: attachment, context: context),
      dispose: (state) {
        state.controller?.navigated = true;
      },
      builder: (controller) {
        return VisibilityDetector(
          onVisibilityChanged: (info) {
            if (info.visibleFraction == 0 && controller.isVisible && !controller.navigated) {
              controller.isVisible = false;
              controller.controller.pause();
              controller.showPlayPauseOverlay.value = true;
              if (SettingsManager().settings.lowMemoryMode.value) {
                CurrentChat.of(context)?.clearImageData(attachment);
              }
            } else if (!controller.isVisible) {
              controller.isVisible = true;
            }
          },
          key: Key(attachment.guid!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: AnimatedSize(
              vsync: controller,
              curve: Curves.easeInOut,
              alignment: Alignment.center,
              duration: Duration(milliseconds: 250),
              child: Obx(() => buildPlayer(controller, context)),
            ),
          ),
        );
      },
    );
  }

  Widget buildPlayer(VideoWidgetController controller, BuildContext context) => GestureDetector(
        onTap: () async {
          if (controller.controller.value.isPlaying) {
            controller.controller.pause();
            controller.showPlayPauseOverlay.value = true;
          } else {
            controller.navigated = true;
            CurrentChat? currentChat = CurrentChat.of(context);
            await Navigator.of(context).push(
              ThemeSwitcher.buildPageRoute(
                builder: (context) => AttachmentFullscreenViewer(
                  currentChat: currentChat,
                  attachment: attachment,
                  showInteractions: true,
                ),
              ),
            );
            controller.navigated = false;
          }
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: CustomNavigator.width(context) / 2,
            maxHeight: context.height / 2,
          ),
          child: Hero(
            tag: attachment.guid!,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: controller.controller.value.aspectRatio,
                  child: Stack(
                    children: <Widget>[
                      if (kIsDesktop) Video(player: controller.desktopController),
                      if (!kIsDesktop) VideoPlayer(controller.controller),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: controller.showPlayPauseOverlay.value ? 1 : 0,
                  duration: Duration(milliseconds: 250),
                  child: Container(
                    decoration: BoxDecoration(
                      color: HexColor('26262a').withOpacity(0.5),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    padding: EdgeInsets.all(10),
                    child: controller.controller.value.isPlaying
                        ? GestureDetector(
                            child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS ? CupertinoIcons.pause : Icons.pause,
                              color: Colors.white,
                              size: 45,
                            ),
                            onTap: () {
                              controller.controller.pause();
                              controller.showPlayPauseOverlay.value = true;
                            },
                          )
                        : GestureDetector(
                            child: Icon(
                              SettingsManager().settings.skin.value == Skins.iOS
                                  ? CupertinoIcons.play
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 45,
                            ),
                            onTap: () {
                              controller.controller.play();
                              controller.showPlayPauseOverlay.value = false;
                            },
                          ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                      child: AnimatedOpacity(
                        opacity: controller.showPlayPauseOverlay.value ? 1 : 0,
                        duration: Duration(milliseconds: 250),
                        child: AbsorbPointer(
                          absorbing: !controller.showPlayPauseOverlay.value,
                          child: GestureDetector(
                            onTap: () {
                              controller.muted.toggle();
                              controller.controller.setVolume(controller.muted.value ? 0.0 : 1.0);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: HexColor('26262a').withOpacity(0.5),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              padding: EdgeInsets.all(5),
                              child: Obx(() => Icon(
                                    controller.muted.value
                                        ? SettingsManager().settings.skin.value == Skins.iOS
                                            ? CupertinoIcons.volume_mute
                                            : Icons.volume_mute
                                        : SettingsManager().settings.skin.value == Skins.iOS
                                            ? CupertinoIcons.volume_up
                                            : Icons.volume_up,
                                    color: Colors.white,
                                    size: 15,
                                  )),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
