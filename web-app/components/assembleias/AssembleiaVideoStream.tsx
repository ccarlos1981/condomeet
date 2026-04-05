"use client";

import React, { useEffect, useState } from "react";
import { Video, AlertCircle } from "lucide-react";

// Setup App ID
const APP_ID = process.env.NEXT_PUBLIC_AGORA_APP_ID || "";

interface AssembleiaVideoStreamProps {
  assembleiaId: string;
  isBroadcasting: boolean;
  micOn: boolean;
  videoOn: boolean;
}

export function AssembleiaVideoStream({ assembleiaId, isBroadcasting, micOn, videoOn }: AssembleiaVideoStreamProps) {
  const [isClient, setIsClient] = useState(false);
  const [AgoraComponents, setAgoraComponents] = useState<{
    AgoraRTCProvider: React.ComponentType<{ client: unknown; children: React.ReactNode }>;
    VideoStreamContent: React.ComponentType<{ roomId: string; isBroadcasting: boolean; micOn: boolean; videoOn: boolean }>;
    agoraClient: unknown;
  } | null>(null);

  useEffect(() => {
    setIsClient(true);
  }, []);

  // Dynamically import Agora SDK only on client side
  useEffect(() => {
    if (!isClient || !APP_ID) return;

    const loadAgora = async () => {
      try {
        const AgoraRTC = (await import("agora-rtc-sdk-ng")).default;
        const agoraReact = await import("agora-rtc-react");
        
        const client = AgoraRTC.createClient({ mode: "live", codec: "vp8" });
        
        // Create the inner component dynamically
        const InnerContent = function VideoContent({ roomId, isBroadcasting: broadcasting, micOn: mic, videoOn: vid }: { 
          roomId: string; isBroadcasting: boolean; micOn: boolean; videoOn: boolean 
        }) {
          const connectionState = agoraReact.useConnectionState();
          const { localMicrophoneTrack } = agoraReact.useLocalMicrophoneTrack(broadcasting);
          const { isLoading: isLoadingCam, localCameraTrack } = agoraReact.useLocalCameraTrack(broadcasting);

          useEffect(() => {
            client.setClientRole("host");
          }, []);

          useEffect(() => {
            if (localMicrophoneTrack) {
              localMicrophoneTrack.setMuted(!mic);
            }
          }, [mic, localMicrophoneTrack]);

          useEffect(() => {
            if (localCameraTrack) {
              localCameraTrack.setMuted(!vid);
            }
          }, [vid, localCameraTrack]);

          agoraReact.useJoin(
            { appid: APP_ID, channel: roomId, token: null },
            broadcasting
          );

          agoraReact.usePublish([localMicrophoneTrack, localCameraTrack]);

          const isConnecting = connectionState === "CONNECTING" || connectionState === "RECONNECTING";

          return (
            <div className="absolute inset-0 w-full h-full bg-black flex items-center justify-center z-0">
              <div className="absolute inset-0 z-0 flex items-center justify-center opacity-[0.03]">
                <Video size={200} className="text-white" />
              </div>

              {!broadcasting ? (
                <div className="absolute inset-0 bg-gray-900/40 flex flex-col items-center justify-center z-10 backdrop-blur-3xl transition-all duration-700">
                  <div className="w-28 h-28 rounded-[2rem] bg-gray-800/80 flex items-center justify-center text-4xl text-gray-500 shadow-2xl mb-6 ring-1 ring-white/5 shadow-black/50">
                    <Video size={48} strokeWidth={1.5} />
                  </div>
                  <h2 className="text-white text-xl font-bold mb-2">Transmissão Offline</h2>
                  <p className="text-gray-400 text-sm max-w-xs text-center font-medium">
                    Clique em &quot;Iniciar Sessão&quot; abaixo para ligar sua câmera e iniciar o vídeo ao vivo.
                  </p>
                </div>
              ) : (
                <>
                  {(isLoadingCam || isConnecting) && (
                    <div className="absolute inset-0 bg-gray-900/60 flex flex-col items-center justify-center z-10 backdrop-blur-md">
                      <div className="animate-spin w-10 h-10 border-4 border-[#FC5931]/30 border-t-[#FC5931] rounded-full mb-4"></div>
                      <p className="text-white/80 font-medium tracking-wider text-sm uppercase">Conectando ao Estúdio...</p>
                    </div>
                  )}

                  {localCameraTrack && (
                    <div className="w-full h-full overflow-hidden animate-in fade-in duration-1000 bg-black">
                      <agoraReact.LocalVideoTrack 
                        track={localCameraTrack} 
                        play={true} 
                        className="w-full h-full object-cover" 
                      />
                    </div>
                  )}
                </>
              )}

              {broadcasting && connectionState === "CONNECTED" && !isLoadingCam && (
                <div className="absolute top-4 left-4 z-20 flex gap-2">
                   <div className="bg-red-500/20 backdrop-blur-md border border-red-500/30 text-white rounded-full px-3 py-1 flex items-center gap-2 text-[10px] uppercase font-black tracking-widest shadow-lg">
                     <div className="w-2 h-2 rounded-full bg-red-500 animate-pulse"></div>
                     NO AR
                   </div>
                </div>
              )}
            </div>
          );
        };

        setAgoraComponents({
          AgoraRTCProvider: agoraReact.AgoraRTCProvider as unknown as React.ComponentType<{ client: unknown; children: React.ReactNode }>,
          VideoStreamContent: InnerContent,
          agoraClient: client,
        });
      } catch (err) {
        console.error("Erro ao carregar Agora SDK:", err);
      }
    };

    loadAgora();
  }, [isClient]);

  // If no APP_ID is set in env, show a warning placeholder
  if (!APP_ID) {
    return (
      <div className="absolute inset-0 bg-gray-900 flex flex-col items-center justify-center z-10">
        <div className="w-20 h-20 rounded-full bg-red-900/50 flex items-center justify-center text-red-400 mb-4 ring-1 ring-red-500/20">
          <AlertCircle size={32} />
        </div>
        <h3 className="text-white font-bold mb-2">Agora App ID Ausente</h3>
        <p className="text-gray-400 text-sm max-w-sm text-center">
          Configure a variável de ambiente NEXT_PUBLIC_AGORA_APP_ID no seu arquivo .env.local para habilitar a transmissão de vídeo ao vivo.
        </p>
      </div>
    );
  }

  // Loading state while Agora SDK loads
  if (!AgoraComponents) {
    return (
      <div className="absolute inset-0 bg-gray-900 flex flex-col items-center justify-center z-10">
        <div className="animate-spin w-8 h-8 border-3 border-white/20 border-t-white rounded-full mb-3"></div>
        <p className="text-gray-400 text-sm font-medium">Carregando sistema de vídeo...</p>
      </div>
    );
  }

  const { AgoraRTCProvider, VideoStreamContent, agoraClient } = AgoraComponents;

  return (
    <AgoraRTCProvider client={agoraClient}>
      <VideoStreamContent 
        roomId={`assembleia_${assembleiaId}`} 
        isBroadcasting={isBroadcasting} 
        micOn={micOn}
        videoOn={videoOn}
      />
    </AgoraRTCProvider>
  );
}
