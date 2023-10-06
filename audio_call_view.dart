import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app/common/export.dart';
import 'app/data/providers/chat_provider/impl/remote_chat_provider.dart';
import 'app/data/providers/chat_provider/interface/ichat_repostary.dart';

class IncomingAudioCallScreen extends StatefulWidget {
  String? userName;
  Function? onAcceptCall, onRejectCall;

  String? channelName;
  String? token;
  bool? isCaller;

  IncomingAudioCallScreen(
      {this.userName,
      this.onAcceptCall,
      this.onRejectCall,
      this.channelName,
      this.token,
      this.isCaller = false,
      Key? key})
      : super(key: key);

  @override
  State<IncomingAudioCallScreen> createState() =>
      _IncomingVideoCallScreenState();
}

class _IncomingVideoCallScreenState extends State<IncomingAudioCallScreen>
    with WidgetsBindingObserver {
  int? _remoteUid;
  bool _localUserJoined = false;

  bool? isMute = false;
  Timer? timer, countDownTimer;
  IChatRepository? iChatRepository;
  int? minutes = 0, seconds = 0;
  int? callDuration = 0;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();

    checkAllTimer();
    iChatRepository = Get.put(RemoteChatProvider());
    startAudioPlayer();
    initAgora();
  }

  startAudioPlayer() async {
    if (widget.isCaller == true) {
      return;
    }
    assetsAudioPlayer.open(
      Audio("assets/audios/ringtone.mp3"),
    );
    assetsAudioPlayer.setLoopMode(LoopMode.playlist);
    assetsAudioPlayer.play();
  }

  //here we will show countdown time
  checkAllTimer() {
    countDownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      callDuration = callDuration! + 1;
      int minutes = callDuration! ~/ 60;
      int seconds = callDuration! % 60;
      setState(() {});
    });
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
    await [Permission.microphone].request();

    //create the engine
    engine = createAgoraRtcEngine();
    await engine?.initialize(const RtcEngineContext(
      appId: Constants.AGORA_APP_ID,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

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
            startTimer();
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) async {
          debugPrint("remote user $remoteUid left channel");
          print("remote user-------- left channel");
          setState(() {
            _remoteUid = null;
          });
          await engine?.leaveChannel();

          Get.back();
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint(
              '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
        },
      ),
    );
    engine?.leaveChannel();
    await engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await engine?.enableAudio();
    if (widget.isCaller == true) {
      await engine?.joinChannel(
        token: widget.token!,
        channelId: widget.channelName!,
        //channelId: channel,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    }
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
              widget.isCaller == true || _remoteUid != null
                  ? callAcceptedWidget()
                  : _remoteUid == null
                      ? onCallingWidget()
                      : callAcceptedWidget()
            ],
          ),
        ));
  }

  onCallingWidget() {
    return Column(
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
              color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.w500),
        ),
        SizedBox(
          height: 10.h,
        ),
        Text(
          widget.userName ?? "",
          style: Utils.textStyleWidget(
              color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.w700),
        ),
        SizedBox(
          height: 200,
        ),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  print("check clciked");
                  await hitApiForCallAccept();

                  setState(() {});
                },
                child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(
                      Icons.call,
                      color: Colors.white,
                      size: 35,
                    )) /*Lottie.asset(Assets.callAcceptJson,
                    height: 100.h, width: 100.w)*/
                ,
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  hitApiForEndCall(status: Constants.callEnd);
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
    );
  }

  callAcceptedWidget() {
    return Column(
      children: [
        SizedBox(
          height: 20.h,
        ),
        GestureDetector(
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
          child: Padding(
            padding: EdgeInsets.all(20.r),
            child: Align(
              alignment: Alignment.topRight,
              child: Image.asset(
                isMute == false ? Assets.muteImage : Assets.unMuteImage,
                height: 40.h,
                width: 40.w,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 50.h,
        ),
        Align(
            alignment: Alignment.topCenter,
            child: Lottie.asset(Assets.waitingCallJson,
                height: 200.w, width: 200.w)),
        SizedBox(
          height: 10.h,
        ),
        Text(
          _remoteUid == null ? "Waiting..." : "Connected",
          style: Utils.textStyleWidget(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w500),
        ),
        SizedBox(
          height: 10.h,
        ),
        _remoteUid != null
            ? Text(
                // "${callDuration! ~/ 60}:${ callDuration! % 60}",
                "${callDuration! ~/ 60 < 10 ? "0${callDuration! ~/ 60}" : callDuration! ~/ 60}:${callDuration! % 60 < 10 ? "0${callDuration! % 60}" : callDuration! % 60} ",
                style: Utils.textStyleWidget(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800),
              )
            : SizedBox(),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            hitApiForEndCall(status: Constants.callEnd);
          },
          child: Align(
            alignment: Alignment.center,
            child: Image.asset(
              Assets.callEndImage,
              height: 70.h,
              width: 70.w,
            ),
          ),
        ),
        SizedBox(
          height: 50.h,
        )
      ],
    );
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

    if (timer != null) {
      timer?.cancel();
    }

    if (countDownTimer != null) {
      countDownTimer?.cancel();
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

  hitApiForCallAccept({status, channelName, token}) async {
    try {
      Utils.showLoader();
      await iChatRepository?.callingStatusCheck(map: {
        "status": Constants.callAccept,
        "channelName": widget.channelName
      }).then((value) async {
        if (value != null) {
          Utils.hideLoader();
          Utils.showToast(message: value.message ?? "");
          if(assetsAudioPlayer!=null&&assetsAudioPlayer.isPlaying.value){
            assetsAudioPlayer.stop();
          }
          await engine?.joinChannel(
            token: widget.token!,
            channelId: widget.channelName!,
            //channelId: channel,
            uid: 0,
            options: const ChannelMediaOptions(),
          );
          setState(() {});
        }
      });
    } on DioError catch (error) {
      Utils.hideLoader();
      if (error.response != null && error.response!.data != null) {
        Utils.showToast(message: error.response!.data['message']);
      }
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
          Get.back();
          if (countDownTimer != null) {
            countDownTimer?.cancel();
          }
          if(assetsAudioPlayer!=null&&assetsAudioPlayer.isPlaying.value){
            assetsAudioPlayer.stop();
          }
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
}
