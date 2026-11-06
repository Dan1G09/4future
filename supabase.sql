-- 4Future: Supabase setup (prices + multi-buy; safe to re-run). Paste this whole file into Supabase > SQL Editor and press Run (once).
-- Admin password: Ficko (not case sensitive). To change it, edit the word 'ficko' in the _chk function below (lowercase) and run again.

create table if not exists public.orders (
  no text primary key,
  created timestamptz not null default now(),
  status text not null default 'New',
  data jsonb not null
);
create table if not exists public.tickets (
  no text primary key,
  created timestamptz not null default now(),
  status text not null default 'Open',
  data jsonb not null
);
-- Nobody can read or write the tables directly. Everything goes through the functions below.
alter table public.orders enable row level security;
alter table public.tickets enable row level security;
revoke all on table public.orders, public.tickets from anon, authenticated;

create or replace function public._chk(pw text) returns void
language plpgsql as $fn$
begin
  if lower(btrim(coalesce(pw, ''))) <> 'ficko' then
    raise exception 'unauthorized' using errcode = 'PT401';
  end if;
end $fn$;

create or replace function public.place_order(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  cat jsonb := $cat${"copying-machines-cannon-image-runner":{"n":"Cannon Image Runner","p":2695.55},"copying-machines-kyocera-5150":{"n":"Kyocera 5150","p":2499},"copying-machines-samsung-cx25ko":{"n":"Samsung CX25KO","p":3340},"copying-machines-brother-72-pro":{"n":"Brother 72 Pro","p":5750.03},"copying-machines-cannon-common":{"n":"Cannon Common","p":2516.8},"copying-machines-wikimedia-commons":{"n":"Wikimedia Commons","p":2176},"copying-machines-brother-common":{"n":"Brother Common","p":1876},"personal-computers-lenovo-a35":{"n":"Lenovo A35","p":1069},"personal-computers-qrent-p10":{"n":"Qrent P10","p":476},"personal-computers-hp-x10":{"n":"HP X10","p":786},"personal-computers-dell-future":{"n":"Dell Future","p":479},"personal-computers-ibuk-power":{"n":"iBUK Power","p":429},"personal-computers-delta-3f":{"n":"Delta 3F","p":370.37},"personal-computers-transpo-2k":{"n":"Transpo 2K","p":470.47},"personal-computers-aurora":{"n":"Aurora","p":483.34},"laptops-lenovo-v15":{"n":"Lenovo V15","p":1576},"laptops-hp-elitebook":{"n":"HP EliteBook","p":1380},"laptops-lenovo-ideapad":{"n":"Lenovo IdeaPad","p":1100},"laptops-acer-aspire":{"n":"Acer Aspire","p":999},"laptops-asus-vivobook":{"n":"Asus Vivobook","p":989},"laptops-msi-business":{"n":"MSI Business","p":1716.0},"laptops-asus-zen":{"n":"Asus Zen","p":1176},"laptops-lenovo-thinkbook":{"n":"Lenovo ThinkBook","p":1830.4},"laptops-acer-nitro":{"n":"Acer Nitro","p":1477.19},"laptops-huawei-matepad-pro-max":{"n":"HUAWEI Matepad Pro Max","p":1420},"computer-mice-logitech":{"n":"Logitech","p":32},"computer-mice-xiaomi":{"n":"Xiaomi","p":22},"computer-mice-canyon-mw-01":{"n":"Canyon MW-01","p":27.17},"computer-mice-cherry":{"n":"Cherry","p":11},"computer-mice-xiaomi-comfort":{"n":"Xiaomi comfort","p":14.3},"computer-mice-xiaomi-green":{"n":"Xiaomi Green","p":37.18},"computer-mice-asus-rog-harpe-ii-extreme-edition":{"n":"ASUS ROG Harpe II Extreme Edition","p":176},"computer-mice-yesido-kb15":{"n":"Yesido KB15","p":32},"printers-xerox-phaser-6510v-n":{"n":"Xerox Phaser 6510V/N","p":230},"printers-xerox-versalink-c400":{"n":"Xerox Versalink C400","p":1399},"printers-xerox-versalink-b400":{"n":"Xerox Versalink B400","p":318.89},"printers-kyocera-ecosys-p3060dn":{"n":"Kyocera ECOSYS P3060dn","p":656.37},"printers-kyocera-ecosys-p7040cdn":{"n":"Kyocera ECOSYS P7040cdn","p":529},"printers-hp-laserjet-pro-m277dw":{"n":"HP Laserjet Pro M277dw","p":270},"printers-hp-laserjet-enterprise-m605":{"n":"HP Laserjet Enterprise M605","p":409},"printers-hp-laserjet-enterprise-colour-cp4025":{"n":"HP Laserjet Enterprise Colour CP4025","p":576},"printers-canon-maxify-mb5450":{"n":"Canon Maxify MB5450","p":184.47},"printers-canon-i-sensys-lbp710cx-colour-laser-printer":{"n":"Canon i-SENSYS LBP710Cx colour laser printer","p":189},"data-projectors-benq-ms527":{"n":"BenQ MS527","p":129},"data-projectors-epson-eh-tw6700":{"n":"EPSON EH-TW6700","p":284.57},"data-projectors-acer-h5380bd":{"n":"Acer H5380BD","p":227.37},"data-projectors-lumeri-lum200a-b":{"n":"LUMERI LUM200A-B","p":141.57},"data-projectors-lg-ph450ug":{"n":"LG PH450UG","p":199},"data-projectors-philips-ppx4150":{"n":"PHILIPS PPX4150","p":129},"data-projectors-celexon-roller-screen":{"n":"Celexon roller-screen","p":49},"data-projectors-celexon-electric-screen":{"n":"Celexon electric screen","p":76},"data-projectors-optoma-ds-9084pmg-roller-screen":{"n":"Optoma DS-9084PMG+ roller screen","p":69},"data-projectors-optoma-dp-9046mwl":{"n":"Optoma DP-9046MWL","p":85},"phones-t-home-concept-pa624i-landline":{"n":"T-Home Concept PA624i landline","p":49},"phones-telekom-concept-pa415-wired-phone":{"n":"Telekom Concept PA415 wired phone","p":29},"phones-panasonic-kx-ts880-wired-phone":{"n":"Panasonic KX-TS880 wired phone","p":24},"phones-panasonic-kx-tg6822gb-wireless-phone":{"n":"Panasonic KX TG6822GB wireless phone","p":37.18},"phones-gigaset-s850a-go-wireless-phone":{"n":"Gigaset S850A GO wireless phone","p":47.19},"phones-gigaset-sl930a-wireless-phone":{"n":"Gigaset SL930A wireless phone","p":124.41},"phones-panasonic-kx-prw130-wireless-phone":{"n":"Panasonic KX-PRW130 wireless phone","p":39},"phones-gigaset-c430a-wireless-phone":{"n":"Gigaset C430A wireless phone","p":59},"phones-freevoice-nimbus-ii-headset":{"n":"FreeVoice Nimbus II Headset","p":31},"phones-jabro-pro-9465-duo-headset":{"n":"Jabro Pro 9465 DUO Headset","p":43},"document-shredders-ideal-8283cc-document-shredder":{"n":"IDEAL 8283CC Document Shredder","p":370.37},"document-shredders-ideal-8266-bc-document-shredder":{"n":"IDEAL 8266 BC Document Shredder","p":79},"document-shredders-rexel-300x-2103250-shredder":{"n":"Rexel 300X 2103250 Shredder","p":229},"document-shredders-hama-premium-m12cd-shredder":{"n":"Hama Premium M12CD Shredder","p":198.77},"document-shredders-rexel-duo-2102560":{"n":"Rexel DUO 2102560","p":59},"document-shredders-fellowes-450m":{"n":"Fellowes 450M","p":58.63},"document-shredders-fellowes-h-6c":{"n":"Fellowes H-6C","p":33},"document-shredders-hama-premium-x12d":{"n":"Hama Premium X12d","p":51}}$cat$::jsonb;
  c jsonb := coalesce(p->'customer', '{}'::jsonb);
  v_name text := btrim(coalesce(c->>'name', ''));
  v_email text := btrim(coalesce(c->>'email', ''));
  v_phone text := btrim(coalesce(c->>'phone', ''));
  v_country text := btrim(coalesce(c->>'country', ''));
  v_zip text := btrim(coalesce(c->>'zip', ''));
  v_city text := btrim(coalesce(c->>'city', ''));
  v_addr text := btrim(coalesce(c->>'address', ''));
  v_item jsonb; v_prod jsonb; v_q int; v_c numeric; v_line numeric;
  v_items jsonb := '[]'::jsonb;
  v_total numeric := 0;
  v_card jsonb := null;
  v_no text;
begin
  if length(v_name) not between 3 and 80 or v_name ~ '[0-9<>]' or v_name !~ '[[:space:]]' then raise exception 'invalid name'; end if;
  if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]{2,}$' or length(v_email) > 120 then raise exception 'invalid email'; end if;
  if v_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'invalid phone'; end if;
  if length(v_country) not between 2 and 60 or v_country ~ '[0-9<>]' then raise exception 'invalid country'; end if;
  if v_zip !~ '^[A-Za-z0-9][A-Za-z0-9 -]{2,9}$' then raise exception 'invalid zip'; end if;
  if length(v_city) not between 2 and 60 or v_city ~ '[0-9<>]' then raise exception 'invalid city'; end if;
  if length(v_addr) not between 5 and 120 then raise exception 'invalid address'; end if;
  if coalesce(p->>'pay', '') not in ('Bank card', 'Bank transfer', 'Cash on delivery') then raise exception 'invalid payment'; end if;
  if jsonb_typeof(p->'items') is distinct from 'array' or jsonb_array_length(p->'items') not between 1 and 50 then raise exception 'invalid items'; end if;
  for v_item in select value from jsonb_array_elements(p->'items') loop
    v_q := (v_item->>'q')::int;
    v_prod := cat->(v_item->>'id');
    if v_prod is null or v_q < 1 or v_q > 99 then raise exception 'invalid item'; end if;
    -- Multi-buy: 1st unit full price, units 2-4 at -3%, unit 5 and up at -5% (computed in cents).
    v_c := round((v_prod->>'p')::numeric * 100);
    v_line := v_c + round(v_c * 97 / 100) * least(greatest(v_q - 1, 0), 3) + round(v_c * 95 / 100) * greatest(v_q - 4, 0);
    v_items := v_items || jsonb_build_array(jsonb_build_object('id', v_item->>'id', 'n', v_prod->>'n', 'p', (v_prod->>'p')::numeric, 'q', v_q, 'line', round(v_line / 100, 2)));
    v_total := v_total + round(v_line / 100, 2);
  end loop;
  if p->>'pay' = 'Bank card' and (p->'card'->>'last4') ~ '^[0-9]{4}$' then
    v_card := jsonb_build_object('brand', left(coalesce(p->'card'->>'brand', ''), 20), 'last4', p->'card'->>'last4');
  end if;
  v_no := '4F-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 7));
  insert into public.orders(no, data) values (v_no, jsonb_build_object(
    'no', v_no, 'ts', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'customer', jsonb_build_object('name', v_name, 'email', v_email, 'phone', v_phone, 'country', v_country,
                                   'zip', v_zip, 'city', v_city, 'address', v_addr, 'note', left(coalesce(c->>'note', ''), 500)),
    'pay', p->>'pay', 'card', v_card, 'status', 'New', 'total', v_total, 'items', v_items));
  return jsonb_build_object('no', v_no, 'total', v_total);
end $fn$;

create or replace function public.place_ticket(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_name text := btrim(coalesce(p->>'name', ''));
  v_email text := btrim(coalesce(p->>'email', ''));
  v_phone text := btrim(coalesce(p->>'phone', ''));
  v_topic text := btrim(coalesce(p->>'topic', ''));
  v_order text := btrim(coalesce(p->>'order', ''));
  v_msg text := btrim(coalesce(p->>'message', ''));
  v_no text;
begin
  if length(v_name) not between 3 and 80 or v_name ~ '[0-9<>]' or v_name !~ '[[:space:]]' then raise exception 'invalid name'; end if;
  if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]{2,}$' or length(v_email) > 120 then raise exception 'invalid email'; end if;
  if v_phone <> '' and v_phone !~ '^\+?[0-9]{7,15}$' then raise exception 'invalid phone'; end if;
  if v_topic not in ('Order', 'Payment', 'Product question', 'Business / bulk enquiry', 'Other') then raise exception 'invalid topic'; end if;
  if v_order <> '' and v_order !~* '^4F-[A-Z0-9]{4,12}$' then raise exception 'invalid order number'; end if;
  if length(v_msg) not between 10 and 2000 then raise exception 'invalid message'; end if;
  v_no := 'S-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 7));
  insert into public.tickets(no, data) values (v_no, jsonb_build_object(
    'no', v_no, 'ts', (extract(epoch from clock_timestamp()) * 1000)::bigint, 'status', 'Open',
    'name', v_name, 'email', v_email, 'phone', v_phone, 'topic', v_topic, 'order', v_order, 'message', v_msg));
  return jsonb_build_object('no', v_no);
end $fn$;

create or replace function public.admin_list(pw text) returns jsonb
language plpgsql security definer set search_path = public as $fn$
begin
  perform public._chk(pw);
  return jsonb_build_object(
    'orders', (select coalesce(jsonb_agg(data || jsonb_build_object('status', status) order by created desc), '[]'::jsonb) from public.orders),
    'tickets', (select coalesce(jsonb_agg(data || jsonb_build_object('status', status) order by created desc), '[]'::jsonb) from public.tickets));
end $fn$;

create or replace function public.admin_set(pw text, kind text, p_no text, p_status text) returns jsonb
language plpgsql security definer set search_path = public as $fn$
begin
  perform public._chk(pw);
  if kind = 'orders' then
    if p_status not in ('New', 'Processing', 'Shipped', 'Completed', 'Cancelled') then raise exception 'invalid status'; end if;
    update public.orders set status = p_status where no = p_no;
  elsif kind = 'tickets' then
    if p_status not in ('Open', 'In progress', 'Resolved') then raise exception 'invalid status'; end if;
    update public.tickets set status = p_status where no = p_no;
  else
    raise exception 'invalid kind';
  end if;
  return jsonb_build_object('ok', true);
end $fn$;

create or replace function public.admin_delete(pw text, kind text, p_no text) returns jsonb
language plpgsql security definer set search_path = public as $fn$
begin
  perform public._chk(pw);
  if kind = 'orders' then delete from public.orders where no = p_no;
  elsif kind = 'tickets' then delete from public.tickets where no = p_no;
  else raise exception 'invalid kind';
  end if;
  return jsonb_build_object('ok', true);
end $fn$;

revoke all on function public._chk(text) from public, anon, authenticated;
revoke all on function public.place_order(jsonb), public.place_ticket(jsonb), public.admin_list(text),
  public.admin_set(text, text, text, text), public.admin_delete(text, text, text) from public;
grant execute on function public.place_order(jsonb), public.place_ticket(jsonb), public.admin_list(text),
  public.admin_set(text, text, text, text), public.admin_delete(text, text, text) to anon, authenticated;
notify pgrst, 'reload schema';
