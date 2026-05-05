
DROP POLICY IF EXISTS "System funds viewable by everyone" ON public.system_funds;
CREATE POLICY "Authenticated can view system funds"
  ON public.system_funds FOR SELECT
  TO authenticated
  USING (true);
