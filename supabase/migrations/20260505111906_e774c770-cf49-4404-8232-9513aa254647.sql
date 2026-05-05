
REVOKE SELECT (talento, potencial_velocidade, potencial_forca, potencial_resistencia, potencial_forma)
  ON public.players FROM anon, authenticated;
