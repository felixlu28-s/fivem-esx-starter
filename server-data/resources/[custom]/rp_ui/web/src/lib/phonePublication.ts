export async function forPublication(blob: Blob) {
  const image = await createImageBitmap(blob);
  try {
    const canvas = document.createElement("canvas"), scale = Math.min(1, 1280 / image.width, 720 / image.height);
    canvas.width = Math.round(image.width * scale); canvas.height = Math.round(image.height * scale);
    canvas.getContext("2d")!.drawImage(image, 0, 0, canvas.width, canvas.height);
    let quality = .8, data = canvas.toDataURL("image/jpeg", quality);
    while (data.length > 115000 && quality > .2) { quality -= .1; data = canvas.toDataURL("image/jpeg", quality); }
    if (data.length > 120000) throw new Error("Dieses Foto ist für einen Beitrag zu groß.");
    return data;
  } finally { image.close(); }
}
