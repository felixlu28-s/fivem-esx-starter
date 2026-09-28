import { useEffect, useRef } from "react";

export function PhoneVideo({ stream, label }: { stream?: MediaStream; label: string }) {
  const ref = useRef<HTMLVideoElement>(null);
  useEffect(() => {
    const video = ref.current;
    if (video) { video.srcObject = stream ?? null; if (stream) void video.play().catch(() => undefined); }
    return () => { if (video) video.srcObject = null; };
  }, [stream]);
  return <figure className="phone-video"><video ref={ref} autoPlay playsInline muted /><figcaption>{label}</figcaption></figure>;
}
