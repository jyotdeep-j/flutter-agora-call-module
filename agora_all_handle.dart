import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app/data/providers/chat_provider/impl/remote_chat_provider.dart';
import 'app/data/providers/chat_provider/interface/ichat_repostary.dart';

const appId = Constants.AGORA_APP_ID;

class AgoraVideoCall extends StatefulWidget {
  String? channelName;
  String? token;

  AgoraVideoCall({this.channelName, this.token, Key? key}) : super(key: key);

  @override
  State<AgoraVideoCall> createState() => _MyAppState();
}

class _MyAppState extends State<AgoraVideoCall> with WidgetsBindingObserver {
  IChatRepository? iChatRepository;
  int? _remoteUid;
  bool _localUserJoined = false;


  bool? isMute = false;
  bool? isVideoEnable = true;
  Timer? timer;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    iChatRepository = Get.put(RemoteChatProvider());
    super.initState();
    startTimer();
    initAgora();
  }

  //check user joined the call
  startTimer() {
    timer = Timer(const Duration(seconds: 30), () {
      if (_remoteUid == null) {
        print("rejected call");
        hitApiForEndCall(status: Constants.callReject);
      }
    });
  }

  Future<void> initAgora() async {
    // retrieve permissions
    await [Permission.microphone, Permission.camera].request();

    //create the engine

    engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          if (mounted) {
            setState(() {
              _localUserJoined = true;
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          //timer?.cancel();
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) async {
          debugPrint("remote user $remoteUid left channel");
          print("remote user-------- left channel");
          setState(() {
            _remoteUid = null;
          });
          await  engine?.leaveChannel();
          await  engine?.release();

          Get.offAllNamed(AppPages.dashboard);
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint(
              '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
        },
      ),
    );
    engine?.leaveChannel();
    await  engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await  engine?.enableVideo();
    await  engine?.startPreview();

    await  engine?.joinChannel(
      token: widget.token!,
      channelId: widget.channelName!,
      //channelId: channel,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  // Create UI with local view and remote view
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        return Future.value(false);
      },
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: _remoteVideo(),
            ),
            Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: callingActionButtonWidget(),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 65.h),
                    width: 120.w,
                    height: 180.w,
                    child: Center(
                      child: _localUserJoined
                          ? GestureDetector(
                              onTap: () {
                                engine?.setRemoteUserPriority(
                                    uid: _remoteUid!,
                                    userPriority: PriorityType.priorityHigh);
                              },
                              child: AgoraVideoView(
                                controller: VideoViewController(
                                  rtcEngine:  engine!,
                                  canvas: const VideoCanvas(uid: 0),
                                ),
                              ),
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  callingActionButtonWidget() {
    return Container(
      padding: EdgeInsets.all(8.r),
      color: AppColors.radishColor.withOpacity(0.7),
      child: Row(
        children: [
          Expanded(
              child: GestureDetector(
            onTap: () async {
              if (isVideoEnable == true) {
                isVideoEnable = false;
                engine?.disableVideo();
                await engine?.stopPreview();
              } else {
                isVideoEnable = true;
                engine?.enableVideo();
                await engine?.startPreview();
              }

              setState(() {});
            },
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                  color: AppColors.transparentColor, shape: BoxShape.circle),
              child: Icon(
                isVideoEnable == true ? Icons.videocam : Icons.videocam_off,
                color: Colors.white,
                size: 25,
              ),
            ),
          )),
          Expanded(
              child: GestureDetector(
            onTap: () async {
              hitApiForEndCall(status: Constants.callEnd);
            },
            child: Image.asset(
              Assets.callEndImage,
              height: 50.h,
              width: 50.w,
            ),
          )),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (isMute == true) {
                  isMute = false;
                  engine?.muteLocalAudioStream(isMute!);
                } else {
                  isMute = true;
                  engine?.muteLocalAudioStream(isMute!);
                }

                setState(() {});
              },
              child: Image.asset(
                isMute == false ? Assets.muteImage : Assets.unMuteImage,
                height: 40.h,
                width: 40.w,
              ),
            ),
          )
        ],
      ),
    );
  }

  // Display remote user's video
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine!,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return SizedBox(
        height: Get.height,
        width: Get.width,
        child: Column(
          children: [
            SizedBox(
              height: 100.h,
            ),
            Lottie.asset(Assets.waitingCallJson, fit: BoxFit.fill),
            Text(
              "Connecting....",
              style: Utils.textStyleWidget(
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
      );
    }
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
          Get.offAllNamed(AppPages.dashboard);

          await engine?.leaveChannel();
          await engine?.release();
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
  Future<void> dispose() async {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

    if (timer != null) {
      timer?.cancel();
    }
    engine?.leaveChannel();
    await engine?.release();

    // TODO: implement dispose
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App is completely killed
      hitApiForEndCall(status: Constants.callEnd);
    }
  }
}
