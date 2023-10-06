import 'dart:async';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'app/common/export.dart';
import 'app/data/providers/chat_provider/impl/remote_chat_provider.dart';
import 'app/data/providers/chat_provider/interface/ichat_repostary.dart';

class IncomingVideoCallScreen extends StatefulWidget {
  String? userName;
  String? channelName;
  Function? onAcceptCall, onRejectCall;

  IncomingVideoCallScreen(
      {this.userName,
      this.channelName,
      this.onAcceptCall,
      this.onRejectCall,
      super.key});

  @override
  State<IncomingVideoCallScreen> createState() =>
      _IncomingVideoCallScreenState();
}

class _IncomingVideoCallScreenState extends State<IncomingVideoCallScreen> {
  Timer? timer;
  IChatRepository? iChatRepository;

  @override
  void initState() {
    iChatRepository = Get.put(RemoteChatProvider());
    startAudioPlayer();
    startTimer();
    // TODO: implement initState
    super.initState();
  }

  //check user joined the call
  startTimer() {
    timer = Timer(const Duration(seconds: 30), () {
      hitApiForEndCall(status: Constants.callReject);
    });
  }

  startAudioPlayer() async {
    assetsAudioPlayer.open(
      Audio("assets/audios/ringtone.mp3"),
    );
    assetsAudioPlayer.setLoopMode(LoopMode.playlist);
    assetsAudioPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () {
          return Future.value(false);
        },
        child: Scaffold(
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.gredFirstColors,
                      AppColors.gredSecondColors
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Column(
                children: [
                  SizedBox(
                    height: 100.h,
                  ),
                  Align(
                      alignment: Alignment.topCenter,
                      child: Lottie.asset(Assets.waitingCallJson,
                          height: 200.w, width: 200.w)),
                  SizedBox(
                    height: 10.h,
                  ),
                  Text(
                    "Calling....",
                    style: Utils.textStyleWidget(
                        color: Colors.white,
                        fontSize: 10.0,
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(
                    height: 10.h,
                  ),
                  Text(
                    widget.userName ?? "",
                    style: Utils.textStyleWidget(
                        color: Colors.white,
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700),
                  ),
                  SizedBox(
                    height: 200,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Get.back();
                            if (widget?.onAcceptCall != null) {
                              if (assetsAudioPlayer != null &&
                                  assetsAudioPlayer.isPlaying.value) {
                                assetsAudioPlayer.stop();
                              }
                              widget.onAcceptCall!();
                            }
                          },
                          child: Lottie.asset(Assets.callAcceptJson,
                              height: 100.h, width: 100.w),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Get.back();
                            if (widget?.onRejectCall != null) {
                              if (assetsAudioPlayer != null &&
                                  assetsAudioPlayer.isPlaying.value) {
                                assetsAudioPlayer.stop();
                              }
                              widget.onRejectCall!();
                            }
                          },
                          child: Container(
                              padding: EdgeInsets.all(10.r),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(
                                Icons.call_end_outlined,
                                color: Colors.white,
                                size: 35,
                              )),
                        ),
                      )
                    ],
                  )
                ],
              )
            ],
          ),
        ));
  }

  hitApiForEndCall({status}) async {
    try {
      Utils.showLoader();
      await iChatRepository?.callingStatusCheck(map: {
        "status": status,
        "channelName": widget.channelName,
      }).then((value) async {
        if (value != null) {
          Utils.hideLoader();
          Get.back();
          if (assetsAudioPlayer != null && assetsAudioPlayer.isPlaying.value) {
            assetsAudioPlayer.stop();
          }
        }
      });
    } on DioError catch (error) {
      Utils.hideLoader();
      if (error.response != null && error.response!.data != null) {
        Utils.showToast(message: error.response!.data['message']);
      }
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    if (audioPlayer != null) {
      if (assetsAudioPlayer != null && assetsAudioPlayer.isPlaying.value) {
        assetsAudioPlayer.stop();
      }
    }
    if (timer != null) {
      timer?.cancel();
    }
  }
}
