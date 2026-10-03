// Emails the student when an admin approves / rejects / asks for more info. Uses Resend (resend.com).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } } });
  const { data: isAdmin } = await sb.rpc("is_admin");
  if (!isAdmin) return json({ error: "Not an admin" }, 403);
  const { id } = await req.json();
  const { data: r } = await sb.from("requests").select("*").eq("id", id).single();
  if (!r || r.status === "Pending") return json({ error: "Request not decided" }, 400);
  const ref = r.id.slice(0, 8).toUpperCase();
  const line: Record<string, string> = {
    "Approved": "Your 3D printing request has been APPROVED.",
    "Rejected": "Unfortunately, your 3D printing request has been REJECTED.",
    "More Info": "We need more information before we can process your 3D printing request.",
  };
  const text = `Dear ${r.name},\n\n${line[r.status]}\n\nRequest: ${ref}\nCourse: ${r.course} (${r.trimester})\nMaterial: ${r.material}\n` +
    (r.admin_note ? `\nMessage from the lab:\n${r.admin_note}\n` : "") + `\nKind regards,\n3D Printing Lab`;
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: Deno.env.get("MAIL_FROM"), to: [r.email],
      subject: `3D Printing Request ${ref} - ${r.status === "More Info" ? "More information needed" : r.status}`, text }),
  });
  if (!res.ok) return json({ error: await res.text() }, 502);
  return json({ ok: true });
});
