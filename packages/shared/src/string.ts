export const encoder = new TextEncoder();
export const decoder = new TextDecoder();

export const encode =
  encoder.encode.bind(encoder);
export const decode =
  decoder.decode.bind(decoder);
