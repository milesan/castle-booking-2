CREATE TABLE public.accommodations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    base_price real NOT NULL,
    type public.accommodation_type NOT NULL,
    inventory integer,
    has_wifi boolean DEFAULT false NOT NULL,
    has_electricity boolean DEFAULT false NOT NULL,
    image_url text,
    is_unlimited boolean DEFAULT false NOT NULL,
    bed_size text,
    bathroom_type text DEFAULT 'none'::text,
    bathrooms numeric DEFAULT 0,
    capacity integer DEFAULT 1 NOT NULL,
    CONSTRAINT accommodations_base_price_check CHECK ((base_price >= (0)::double precision)),
    CONSTRAINT accommodations_inventory_check CHECK ((inventory >= 0))
);


ALTER TABLE public.accommodations OWNER TO postgres;

--
-- Name: accommodation_items_with_tags; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.accommodation_items_with_tags AS
 SELECT ai.id,
    ai.accommodation_id,
    ai.zone,
    ai.type,
    ai.size,
    ai.item_id,
    ai.created_at,
    ai.updated_at,
    public.get_accommodation_item_tag(ai.zone, ai.type, ai.size, ai.item_id) AS full_tag,
    a.title AS accommodation_title,
    a.type AS accommodation_type
   FROM (public.accommodation_items ai
     JOIN public.accommodations a ON ((ai.accommodation_id = a.id)));


ALTER TABLE public.accommodation_items_with_tags OWNER TO postgres;

--
-- Name: applications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.applications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
