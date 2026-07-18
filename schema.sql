-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.profiles (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.profils (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nom text,
  email text UNIQUE,
  plan text DEFAULT 'gratuit'::text,
  date_expiration timestamp without time zone,
  requetes_aujourd_hui integer DEFAULT 0,
  derniere_requete date,
  created_at timestamp without time zone DEFAULT now(),
  classe text,
  credits integer DEFAULT 12,
  email_parent text,
  points integer DEFAULT 0,
  streak integer DEFAULT 0,
  coach_quota_aujourd_hui integer DEFAULT 0,
  derniere_requete_coach text DEFAULT ''::text,
  badges text DEFAULT '[]'::text,
  revisions_rapides_total integer DEFAULT 0,
  premium_classe text,
  premium_expire_at timestamp with time zone,
  suspendu boolean NOT NULL DEFAULT false,
  role text CHECK (role = ANY (ARRAY['learner'::text, 'teacher'::text])),
  CONSTRAINT profils_pkey PRIMARY KEY (id)
);
CREATE TABLE public.evaluations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_email text,
  date text,
  heure text,
  matiere text,
  classe text,
  sa text,
  score integer,
  correct integer,
  partial integer,
  incorrect integer,
  total integer,
  created_at timestamp without time zone DEFAULT now(),
  details jsonb,
  CONSTRAINT evaluations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.evenements (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  email text NOT NULL,
  type text NOT NULL,
  matiere text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT evenements_pkey PRIMARY KEY (id)
);
CREATE TABLE public.conversations (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  email text NOT NULL,
  conv_id text NOT NULL,
  matiere text,
  niveau text,
  mode text,
  apercu text,
  messages jsonb,
  msg_count integer,
  date_str text,
  heure_str text,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT conversations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.classes_enseignant (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  code text NOT NULL UNIQUE,
  nom_classe text NOT NULL,
  matiere text,
  niveau text,
  enseignant_email text NOT NULL,
  enseignant_nom text,
  created_at timestamp with time zone DEFAULT now(),
  chat_ouvert boolean DEFAULT false,
  CONSTRAINT classes_enseignant_pkey PRIMARY KEY (id)
);
CREATE TABLE public.eleves_classe (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  code_classe text NOT NULL,
  eleve_email text NOT NULL,
  eleve_nom text,
  joined_at timestamp with time zone DEFAULT now(),
  CONSTRAINT eleves_classe_pkey PRIMARY KEY (id)
);
CREATE TABLE public.rapports_envoyes (
  id bigint NOT NULL DEFAULT nextval('rapports_envoyes_id_seq'::regclass),
  email text NOT NULL,
  semaine text NOT NULL,
  parent_email text,
  envoye_le timestamp with time zone DEFAULT now(),
  CONSTRAINT rapports_envoyes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.transactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  email text NOT NULL,
  type text NOT NULL,
  montant integer NOT NULL,
  credits_ajoutes integer DEFAULT 0,
  statut text DEFAULT 'approuve'::text,
  CONSTRAINT transactions_pkey PRIMARY KEY (id)
);
CREATE TABLE public.messages_prives (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  expediteur_email text NOT NULL,
  destinataire_email text NOT NULL,
  contenu text NOT NULL,
  lu boolean DEFAULT false,
  code_classe text,
  CONSTRAINT messages_prives_pkey PRIMARY KEY (id)
);
CREATE TABLE public.devoirs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  enseignant_email text NOT NULL,
  code_classe text NOT NULL,
  titre text NOT NULL,
  contenu text NOT NULL,
  date_limite text,
  CONSTRAINT devoirs_pkey PRIMARY KEY (id)
);
CREATE TABLE public.defis (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  challenger_email text NOT NULL,
  challenger_nom text NOT NULL,
  adversaire_email text NOT NULL,
  code_classe text NOT NULL,
  matiere text NOT NULL,
  niveau text NOT NULL,
  statut text DEFAULT 'en_attente'::text,
  score_challenger integer,
  score_adversaire integer,
  questions jsonb,
  notion text,
  CONSTRAINT defis_pkey PRIMARY KEY (id)
);
CREATE TABLE public.messages_classe (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT now(),
  code_classe text NOT NULL,
  expediteur_email text NOT NULL,
  expediteur_nom text NOT NULL,
  contenu text NOT NULL,
  est_enseignant boolean DEFAULT false,
  CONSTRAINT messages_classe_pkey PRIMARY KEY (id)
);
CREATE TABLE public.orders (
  id bigint NOT NULL DEFAULT nextval('orders_id_seq'::regclass),
  reference text NOT NULL UNIQUE,
  user_id uuid NOT NULL,
  user_email text NOT NULL,
  offer_id text NOT NULL,
  type text NOT NULL,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'XOF'::text,
  credits integer NOT NULL DEFAULT 0,
  duration_days integer,
  phone_masked text,
  gateway text NOT NULL DEFAULT 'fedapay'::text,
  gateway_reference text UNIQUE,
  payment_url text,
  status text NOT NULL DEFAULT 'pending'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  paid_at timestamp with time zone,
  processed_at timestamp with time zone,
  CONSTRAINT orders_pkey PRIMARY KEY (id)
);
CREATE TABLE public.rate_limits (
  key text NOT NULL,
  count integer NOT NULL DEFAULT 0,
  window_start timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT rate_limits_pkey PRIMARY KEY (key)
);