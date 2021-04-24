import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'WebRTC Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  RTCPeerConnection _peerConnection;
  MediaStream _localStream;

  final _localRenderer = new RTCVideoRenderer();
  final _remoteRenderer = new RTCVideoRenderer();

  final sdpController = TextEditingController();
  
  // dispose renderer
  @override
  dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  // init renderer
  @override
  void initState() {
    initRenderers();
    _createPeerConnection().then((pc) {
      _peerConnection = pc;
    });
    _getUserMedia();
    super.initState();
  }


  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _createPeerConnection() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url" : "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstrains = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();

    // 피어 커넥트될때까지 대기
    RTCPeerConnection pc = await createPeerConnection(configuration, offerSdpConstrains);

    pc.addStream(_localStream);

    pc.onIceCandidate = (e) {
        if (e.candidate != null) {
          print(json.encode({
            'candidate': e.candidate.toString(),
            'sdpMid': e.sdpMid.toString(),
            'sdpMlineIndex': e.sdpMlineIndex,
          }));
        }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    // 받는 스트림 처리
    pc.onAddStream = (stream) {
      print("addStream: "+stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };

    MediaStream stream = await navigator.getUserMedia(mediaConstraints);

    _localRenderer.srcObject = stream;
    _localRenderer.mirror = true;

    return stream;

  }

  // 피어와 연결 시도해 그 내용을 parse함
  void _createOffer() async {
    
    RTCSessionDescription description =
        await _peerConnection.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp);
    print(json.encode(session));
    _offer = true;

    // print(json.encode({
    //       'sdp': description.sdp.toString(),
    //       'type': description.type.toString(),
    //     }));

    _peerConnection.setLocalDescription(description);
  }

  // 요청받은 피어와 연결
  void _createAnswer() async {
    RTCSessionDescription description = await _peerConnection.createAnswer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp);
    print(json.encode(session));

    _peerConnection.setLocalDescription(description);
  }
  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session =  await jsonDecode('$jsonString');


    String sdp = write(session, null);

    RTCSessionDescription description = new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());

    await _peerConnection.setRemoteDescription(description);
  }
  void _setCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode("$jsonString");
    print(session['candidate']);

    dynamic candidate =
        new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection.addCandidate(candidate);
  }
  SizedBox videoRenderers() => SizedBox(
    height: 210,
    child: Row(
      children: [
        Flexible(
          child: Container(
            key: Key('local'),
            margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
            decoration: BoxDecoration(color: Colors.black),
            child: RTCVideoView(_localRenderer),
          )
        ),
        Flexible(
          child: Container(
            key: Key('remote'),
            margin: EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
            decoration: BoxDecoration(color: Colors.black),
            child: RTCVideoView(_remoteRenderer),
          )
        ),
      ],
    )
  );

  Row offerAndAnswerButtons () => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget> [
      RaisedButton(
        onPressed: _createOffer,
        child:Text("Offer"),
        color: Colors.amber,
      ),
      RaisedButton(
        onPressed: _createAnswer,
        child:Text("Answer"),
        color: Colors.amber,
      )
    ],
  );

  Padding sdpCandidateTF() => Padding(
    padding: const EdgeInsets.all(16.0),
    child: TextField(
      controller: sdpController,
      keyboardType: TextInputType.multiline,
      maxLines: 4,

    )
  );

  Row sdpCandidateButtons() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      RaisedButton(
        onPressed: _setRemoteDescription,
        child: Text("Set Remote Desc."),
        color: Colors.amber,
      ),
      RaisedButton(
        onPressed: _setCandidate,
        child: Text("Set Candidate."),
        color: Colors.amber,
      )
    ],
  );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Container(
        child: Column(
          children: [
            videoRenderers(),
            offerAndAnswerButtons(),
            sdpCandidateTF(),
            sdpCandidateButtons(),
          ],
        )
      )
    );
  }
}
