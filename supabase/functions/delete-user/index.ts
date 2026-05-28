declare const Deno: {
  env: {
    get: (name: string) => string | undefined;
  };
  serve: (handler: (req: Request) => Response | Promise<Response>) => void;
};

// @ts-ignore: URL import is resolved at runtime by Supabase Edge Runtime.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  "Content-Type": "application/json",
  ...corsHeaders,
};

function jsonResponse(status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: jsonHeaders,
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, {
      error: "method_not_allowed",
      message: "Use POST for delete-user.",
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return jsonResponse(500, {
      error: "server_misconfigured",
      message: "Missing required Supabase environment variables.",
    });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse(401, {
      error: "missing_token",
      message: "Authorization Bearer token is required.",
    });
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const {
    data: { user: requester },
    error: requesterError,
  } = await userClient.auth.getUser();
  if (requesterError || !requester) {
    return jsonResponse(401, {
      error: "invalid_token",
      message: requesterError?.message ?? "Invalid user token.",
    });
  }

  let body: { user_id?: unknown; confirm?: unknown; soft_delete?: unknown } = {};
  try {
    const parsedBody = await req.json();
    if (parsedBody && typeof parsedBody === "object") {
      body = parsedBody as { user_id?: unknown; confirm?: unknown; soft_delete?: unknown };
    }
  } catch {
    return jsonResponse(400, {
      error: "invalid_body",
      message: "Body must be valid JSON.",
    });
  }

  const targetUserId =
    typeof body.user_id === "string" && body.user_id.trim().length > 0
      ? body.user_id.trim()
      : requester.id;
  const isSelfDelete = targetUserId == requester.id;

  if (body.confirm !== true) {
    return jsonResponse(400, {
      error: "confirmation_required",
      message: "Set confirm=true in request body to delete a user.",
    });
  }

  if (!isSelfDelete) {
    const { data: profil, error: profilError } = await adminClient
      .from("user_profil")
      .select("data")
      .eq("uid", requester.id)
      .maybeSingle();

    if (profilError) {
      return jsonResponse(403, {
        error: "admin_check_failed",
        message: profilError.message,
      });
    }

    const rules = (profil as { data?: { rule?: unknown } } | null)?.data?.rule;
    const isAdmin =
      Array.isArray(rules) &&
      rules.some((value) => typeof value === "string" && value.toLowerCase() === "admin");

    if (!isAdmin) {
      return jsonResponse(403, {
        error: "forbidden",
        message: "Only admins can delete another user.",
      });
    }
  }

  // Keep profile table consistent after account deletion.
  await adminClient.from("user_profil").delete().eq("uid", targetUserId);

  const shouldSoftDelete = body.soft_delete === true;
  const { error: deleteError } = await adminClient.auth.admin.deleteUser(
    targetUserId,
    shouldSoftDelete,
  );

  if (deleteError) {
    return jsonResponse(400, {
      error: "delete_failed",
      message: deleteError.message,
    });
  }

  return jsonResponse(200, {
    success: true,
    deleted_user_id: targetUserId,
    deleted_by: requester.id,
    self_delete: isSelfDelete,
    soft_delete: shouldSoftDelete,
    timestamp: new Date().toISOString(),
  });
});
