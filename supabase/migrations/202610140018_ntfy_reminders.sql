BEGIN;
ALTER TABLE public.crm_actions ADD COLUMN IF NOT EXISTS ntfy_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS follow_up_on date;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS follow_up_reason text;
ALTER TABLE public.contacts ADD COLUMN IF NOT EXISTS ntfy_enabled boolean NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS crm_ntfy_due_idx ON public.crm_actions(due_date) WHERE ntfy_enabled AND status IN('planned','waiting');
CREATE INDEX IF NOT EXISTS contact_ntfy_due_idx ON public.contacts(follow_up_on) WHERE ntfy_enabled AND is_active;
CREATE OR REPLACE FUNCTION app_private.check_ntfy_due_date() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.ntfy_enabled AND ((TG_TABLE_NAME='contacts' AND to_jsonb(NEW)->>'follow_up_on' IS NULL) OR (TG_TABLE_NAME='crm_actions' AND to_jsonb(NEW)->>'due_date' IS NULL)) THEN
  RAISE EXCEPTION 'Choisissez une date de relance avant d’activer le rappel ntfy.';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION app_private.check_ntfy_due_date() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS check_ntfy_due_date ON public.contacts;
CREATE TRIGGER check_ntfy_due_date BEFORE INSERT OR UPDATE ON public.contacts FOR EACH ROW EXECUTE FUNCTION app_private.check_ntfy_due_date();
DROP TRIGGER IF EXISTS check_ntfy_due_date ON public.crm_actions;
CREATE TRIGGER check_ntfy_due_date BEFORE INSERT OR UPDATE ON public.crm_actions FOR EACH ROW EXECUTE FUNCTION app_private.check_ntfy_due_date();

CREATE TABLE IF NOT EXISTS public.notification_runs(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),slot text NOT NULL UNIQUE CHECK(length(slot)<=96),
 state text NOT NULL DEFAULT 'sending' CHECK(state IN('sending','sent','empty','failed','uncertain')),
 lease uuid NOT NULL DEFAULT gen_random_uuid(),attempts integer NOT NULL DEFAULT 1,
 action_count integer NOT NULL DEFAULT 0 CHECK(action_count>=0),contact_count integer NOT NULL DEFAULT 0 CHECK(contact_count>=0),
 error_code text CHECK(error_code IN('provider_rejected','delivery_uncertain')),created_at timestamptz NOT NULL DEFAULT now(),completed_at timestamptz
);
ALTER TABLE public.notification_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.notification_runs FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.notification_runs TO authenticated;
GRANT ALL ON public.notification_runs TO service_role;
DROP POLICY IF EXISTS admin_read ON public.notification_runs;
CREATE POLICY admin_read ON public.notification_runs FOR SELECT TO authenticated USING(app_private.is_admin());

-- Le serveur ne reçoit que des nombres. Aucun nom, téléphone, courriel ou contenu de note.
CREATE OR REPLACE FUNCTION public.ntfy_digest(p_today date) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actions integer;contacts integer;late_actions integer;late_contacts integer;
BEGIN
 IF p_today IS NULL THEN RAISE EXCEPTION 'Date requise.'; END IF;
 SELECT count(*),count(*) FILTER(WHERE a.due_date<p_today) INTO actions,late_actions FROM public.crm_actions a JOIN public.contacts c ON c.id=a.contact_id AND c.is_active
 WHERE a.ntfy_enabled AND a.status IN('planned','waiting') AND a.due_date<=p_today;
 SELECT count(*),count(*) FILTER(WHERE follow_up_on<p_today) INTO contacts,late_contacts FROM public.contacts
 WHERE ntfy_enabled AND is_active AND follow_up_on<=p_today;
 RETURN jsonb_build_object('actions',actions,'contacts',contacts,'overdue_actions',late_actions,'overdue_contacts',late_contacts);
END $$;
CREATE OR REPLACE FUNCTION public.claim_notification_run(p_slot text,p_actions integer,p_contacts integer) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r public.notification_runs%rowtype;
BEGIN
 IF p_slot IS NULL OR p_slot!~'^(daily:[0-9]{4}-[0-9]{2}-[0-9]{2}|test:[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2})$' OR p_actions IS NULL OR p_contacts IS NULL OR p_actions<0 OR p_contacts<0 THEN RAISE EXCEPTION 'Créneau de notification invalide.'; END IF;
 INSERT INTO public.notification_runs(slot,action_count,contact_count) VALUES(p_slot,p_actions,p_contacts)
 ON CONFLICT(slot) DO UPDATE SET state='sending',lease=gen_random_uuid(),attempts=public.notification_runs.attempts+1,completed_at=NULL,error_code=NULL,action_count=excluded.action_count,contact_count=excluded.contact_count
 WHERE public.notification_runs.state='failed'
 RETURNING * INTO r;
 IF NOT FOUND THEN RETURN jsonb_build_object('claimed',false); END IF;
 RETURN jsonb_build_object('claimed',true,'id',r.id,'lease',r.lease);
END $$;
CREATE OR REPLACE FUNCTION public.finish_notification_run(p_id uuid,p_lease uuid,p_state text,p_error_code text DEFAULT NULL) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_state IS NULL OR p_state NOT IN('sent','empty','failed','uncertain') OR (p_state='failed' AND p_error_code IS DISTINCT FROM 'provider_rejected') OR (p_state='uncertain' AND p_error_code IS DISTINCT FROM 'delivery_uncertain') OR (p_state IN('sent','empty') AND p_error_code IS NOT NULL) THEN RAISE EXCEPTION 'État de notification invalide.'; END IF;
 UPDATE public.notification_runs SET state=p_state,error_code=p_error_code,completed_at=now() WHERE id=p_id AND lease=p_lease AND state='sending';
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION public.ntfy_digest(date),public.claim_notification_run(text,integer,integer),public.finish_notification_run(uuid,uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.ntfy_digest(date),public.claim_notification_run(text,integer,integer),public.finish_notification_run(uuid,uuid,text,text) TO service_role;
COMMIT;
