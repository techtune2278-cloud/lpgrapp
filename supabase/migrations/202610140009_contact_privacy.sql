BEGIN;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS marketing_status text NOT NULL DEFAULT 'unknown' CHECK(marketing_status IN('unknown','opted_in','opted_out'));
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS marketing_evidence text;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS marketing_opt_out_at timestamptz;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS processing_basis text NOT NULL DEFAULT 'unspecified' CHECK(processing_basis IN('unspecified','contract','legal_obligation','legitimate_interest','consent'));
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS privacy_notice_version text;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS last_inbound_on date;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS retention_review_on date;
CREATE OR REPLACE FUNCTION public.check_contact_privacy() RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF NEW.marketing_status='opted_in' AND length(trim(coalesce(NEW.marketing_evidence,'')))<5 THEN RAISE EXCEPTION 'Indiquez la preuve, la date et le canal du consentement avant de le déclarer documenté.'; END IF;
 IF NEW.marketing_status='opted_out' THEN NEW.marketing_opt_out_at=coalesce(NEW.marketing_opt_out_at,now()); END IF;
 IF TG_OP='UPDATE' AND OLD.marketing_status='opted_out' AND NEW.marketing_status='opted_in' AND NEW.marketing_evidence IS NOT DISTINCT FROM OLD.marketing_evidence THEN RAISE EXCEPTION 'Une opposition exige une nouvelle preuve de consentement avant toute réactivation.'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.check_contact_privacy() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS contact_privacy_check ON public.contacts;
CREATE TRIGGER contact_privacy_check BEFORE INSERT OR UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION public.check_contact_privacy();
COMMIT;
