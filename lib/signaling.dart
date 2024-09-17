
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallBack = void Function(MediaStream mediaStream);

class Signaling{

  final Map<String , dynamic> configuration = {
    'iceServers' : [
      {
        'urls' : [
          'stun2.l.google.com:19302',
          'stun3.l.google.com:19302',
        ]
      }
    ]
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentRoomId;
  StreamStateCallBack? onAddRemoteStream;


  Future<String> createRoom(RTCVideoRenderer remoteRenderer)async{
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc();

    peerConnection =await createPeerConnection(configuration);
    registerPeerConnectionListener();


    var callerIceCandidatesCollection = roomRef.collection('callerCandidates');


    // LISTEN TO NEW ICE CANDIDATES AND ADD THEM TO DATE BASE
    peerConnection?.onIceCandidate = (RTCIceCandidate candidate){
      callerIceCandidatesCollection.add(candidate.toMap());
    };

    RTCSessionDescription offer = await peerConnection!.createOffer();

    // CREATE AND SET LOCAL SDP
    await peerConnection!.setLocalDescription(offer);

    await roomRef.set('offer : ${offer.toMap()}');

    roomId = roomRef.id;


    // GET LOCAL STREAM TRACKS SUCH AS CAMERA VIDEO , SCREEN SHARE , AUDIO
    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track , localStream!);
    },);


    //  LISTEN TO NEW TRACKS THAT COME FROM PEER CONNECTION AND ADD THEM TO REMOTE STREAM
    peerConnection?.onTrack = (RTCTrackEvent event){
     final remoteTrack = event.streams[0];
     remoteTrack.getTracks().forEach((track) {
      remoteStream?.addTrack(track);
     },);
    };

    return 'roomId';
  }


  Future<String> joinRoom(String roomId)async{
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('rooms').doc(roomId);
    final DocumentSnapshot roomSnapshot =await roomRef.get();

    if(roomSnapshot.exists){
      peerConnection =await createPeerConnection(configuration);
      registerPeerConnectionListener();

      // GET LOCAL STREAM TRACKS SUCH AS CAMERA VIDEO , SCREEN SHARE , AUDIO
      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track , localStream!);
      },);


      //  LISTEN TO NEW TRACKS THAT COME FROM PEER CONNECTION AND ADD THEM TO REMOTE STREAM
      peerConnection?.onTrack = (RTCTrackEvent event){
        final remoteTrack = event.streams[0];
        remoteTrack.getTracks().forEach((track) {
          remoteStream?.addTrack(track);
        },);

      };

    }
    return 'roomId';
  }

  //  GET LOCAL AND REMOTE MEDIA TO SHOW IN MAIN PAGE
 Future<void> openUserMedia(
     RTCVideoRenderer localVideo,
     RTCVideoRenderer remoteVideo,
     )async{
   MediaStream stream =await navigator.mediaDevices.getUserMedia({'video' : true , 'audio' : true});

   localVideo.srcObject = stream;
   localStream = stream;

   remoteVideo.srcObject =await createLocalMediaStream('key');
  }

  // THE NAME SPEAK FOR HER SELF :)
  Future<void> hangUp(RTCVideoRenderer localVideo)async{
    List<MediaStreamTrack>? tracks = localVideo.srcObject?.getTracks();
    tracks?.forEach((track ) {
      track.stop();
    },);

    if(remoteStream != null){
      remoteStream!.getTracks().forEach((track) =>track.stop());
    }

    if(peerConnection != null) peerConnection!.close();

    if(roomId != null){
      final FirebaseFirestore db = FirebaseFirestore.instance;
      DocumentReference roomRef = db.collection('rooms').doc(roomId);

      var calleeCandidates =await roomRef.collection('calleeCandidates').get();
      calleeCandidates.docs.forEach((element) => element.reference.delete(),);

      var callerCandidates = await roomRef.collection('callerCandidates').get();
      callerCandidates.docs.forEach((element) => element.reference.delete,);

      await roomRef.delete();
    }
    localStream?.dispose();
    remoteStream?.dispose();
  }


 void registerPeerConnectionListener(){
  peerConnection?.onIceGatheringState = (RTCIceGatheringState state){

  };

  peerConnection?.onConnectionState = (RTCPeerConnectionState state){

  };

  peerConnection?.onSignalingState = (RTCSignalingState state){

  };

  peerConnection?.onAddStream = (MediaStream stream){
  onAddRemoteStream?.call(stream);
  remoteStream = stream;
  };

  }
}