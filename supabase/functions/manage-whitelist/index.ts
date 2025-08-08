import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

interface AddUserPayload {
  action: 'add';
  email: string;
}

interface RemoveUserPayload {
  action: 'remove';
  userId: string;
}

type RequestPayload = AddUserPayload | RemoveUserPayload;

function getSupabaseAdminClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get('BACKEND_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('Missing Supabase URL or Service Role Key environment variables.')
    throw new Error('Server configuration error.')
  }
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const payload = await req.json() as RequestPayload
    const supabaseAdmin = getSupabaseAdminClient()

    // Check if the requesting user is an admin
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'No authorization header' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token)
    
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 401,
      })
    }

    // Check if user is admin
    const { data: profile } = await supabaseAdmin
      .from('profiles')
      .select('is_admin')
      .eq('id', user.id)
      .single()

    if (!profile?.is_admin) {
      return new Response(JSON.stringify({ error: 'Admin access required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    if (payload.action === 'add') {
      const normalizedEmail = payload.email.toLowerCase().trim()
      
      // Check if user already exists
      const { data: existingUser } = await supabaseAdmin
        .from('profiles')
        .select('id')
        .eq('email', normalizedEmail)
        .single()

      if (existingUser) {
        return new Response(JSON.stringify({ 
          error: 'User already exists in whitelist' 
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        })
      }

      // Create auth user
      const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
        email: normalizedEmail,
        email_confirm: true,
        user_metadata: {
          whitelisted: true
        }
      })

      if (authError) {
        console.error('Error creating auth user:', authError)
        return new Response(JSON.stringify({ 
          error: authError.message 
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        })
      }

      if (authData.user) {
        // Create profile entry
        const { error: profileError } = await supabaseAdmin
          .from('profiles')
          .insert({
            id: authData.user.id,
            email: normalizedEmail,
            created_at: new Date().toISOString()
          })

        if (profileError) {
          // Cleanup on failure
          await supabaseAdmin.auth.admin.deleteUser(authData.user.id)
          console.error('Error creating profile:', profileError)
          return new Response(JSON.stringify({ 
            error: 'Failed to create user profile' 
          }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 500,
          })
        }

        return new Response(JSON.stringify({ 
          success: true,
          userId: authData.user.id,
          email: normalizedEmail
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        })
      }
    } else if (payload.action === 'remove') {
      // Delete auth user (profile will cascade delete)
      const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(payload.userId)
      
      if (deleteError) {
        console.error('Error deleting user:', deleteError)
        return new Response(JSON.stringify({ 
          error: 'Failed to remove user' 
        }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500,
        })
      }

      return new Response(JSON.stringify({ 
        success: true,
        userId: payload.userId
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    return new Response(JSON.stringify({ 
      error: 'Invalid action' 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })

  } catch (error) {
    console.error('Error:', error)
    return new Response(JSON.stringify({ 
      error: error.message || 'Internal server error'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})