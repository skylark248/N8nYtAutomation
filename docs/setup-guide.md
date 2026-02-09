# YouTube Shorts Workflow - Complete Setup Guide

## Prerequisites
- n8n running locally in Docker at http://localhost:5678
- OpenAI account with API billing enabled
- Google account with a YouTube channel
- Creatomate account (free tier)

---

## Credential 1: OpenAI API

**Used by**: Generate Script (GPT-5)

### Get API Key
1. Go to [platform.openai.com](https://platform.openai.com)
2. Sign in (same account as ChatGPT, but API billing is separate)
3. Click **"API keys"** in the left sidebar
4. Click **"Create new secret key"**
5. Copy the key (starts with `sk-...`) — you won't see it again

### Add Billing
1. Go to platform.openai.com → **Settings** → **Billing**
2. Click **"Add payment method"**
3. Add $10-20 to start (prepaid credits, pay-per-use)
4. This is separate from your ChatGPT subscription

### Add to n8n
1. Open your imported workflow in n8n
2. Click on **"Generate Script (GPT-5)"** node
3. Click **"Credential to connect with"** → **"Create New Credential"**
4. Select **"OpenAI API"**
5. Paste your API key
6. Click **"Save"**

### Verify
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer sk-your-key-here" \
  | head -20
```
Should return a list of available models.

---

## Credential 2: HTTP Header Auth (OpenAI TTS)

**Used by**: Generate Images (DALL-E 3), Generate Voiceover (TTS)

This is the same API key as above, but wrapped in Header Auth format because the DALL-E and TTS nodes use raw HTTP Requests.

### Add to n8n
1. Click on the **"Generate Voiceover (TTS)"** node
2. Click **"Credential to connect with"** → **"Create New Credential"**
3. Select **"Header Auth"**
4. Fill in:
   - **Name**: `Authorization`
   - **Value**: `Bearer sk-your-same-openai-api-key`
5. Click **"Save"**

---

## Credential 3: Creatomate (Video Composition)

**Used by**: Compose Video (Creatomate), Check Render Status

### Create Account
1. Go to [creatomate.com](https://creatomate.com)
2. Click **"Start Free Trial"** (no credit card needed)
3. Sign up with email or Google

### Get API Key
1. After login, click your **profile icon** (top-right) → **"Project Settings"**
2. Or go to **Settings** → **API**
3. Copy your **API Key**

### Create Slideshow Template
1. Click **"New Template"** → **"Blank"**
2. Set canvas:
   - Width: **1080**
   - Height: **1920**
   - (9:16 vertical — YouTube Shorts format)
3. Set duration: **45 seconds**
4. Add 4 Image elements:
   - Click **"+"** → **"Image"**
   - Name each one exactly: `Image-1`, `Image-2`, `Image-3`, `Image-4`
   - Each image should:
     - Fill the full canvas (1080x1920)
     - Display for ~10-11 seconds
     - Have a fade/dissolve transition to the next
   - Use any placeholder image while designing — the workflow replaces them at runtime
5. Add 1 Audio element:
   - Click **"+"** → **"Audio"**
   - Name it exactly: `Audio`
   - Set to play for the full 45 seconds
6. Click **"Save"**

### Get Template ID
- From the URL: `https://creatomate.com/projects/.../templates/TEMPLATE_ID`
- The template ID is the last UUID segment
- Example: `d81159ea-05df-4892-b043-2980aeb4e0bf`

### Add Credential to n8n
1. Click on the **"Compose Video (Creatomate)"** node
2. Click **"Credential to connect with"** → **"Create New Credential"**
3. Select **"Header Auth"**
4. Fill in:
   - **Name**: `Authorization`
   - **Value**: `Bearer your-creatomate-api-key`
5. Click **"Save"**

### Update Template ID in Workflow
1. Still in the **"Compose Video (Creatomate)"** node
2. Find `YOUR_TEMPLATE_ID` in the JSON body
3. Replace with your actual template ID
4. Save the workflow

### Free Tier Limits
- 10 renders/month
- 1080p max resolution
- Check creatomate.com/pricing for current terms

---

## Credential 4: YouTube OAuth2

**Used by**: Upload to YouTube node

### Step 1: Create Google Cloud Project
1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Sign in with the **same Google account** as your YouTube channel
3. Click the project dropdown (top-left) → **"New Project"**
4. Name: `n8n YouTube Automation` → **Create**
5. Make sure this new project is selected in the dropdown

### Step 2: Enable YouTube Data API v3
1. Go to **APIs & Services** → **Library** (left sidebar)
2. Search for **"YouTube Data API v3"**
3. Click it → **"Enable"**

### Step 3: Configure OAuth Consent Screen
1. Go to **APIs & Services** → **OAuth consent screen**
2. Select **"External"** → **Create**
3. Fill in:
   - App name: `n8n YouTube`
   - User support email: your email
   - Developer contact email: your email
4. Click **"Save and Continue"**
5. **Scopes** page:
   - Click **"Add or Remove Scopes"**
   - Search and add: `youtube.upload`
   - Search and add: `youtube` (or `youtube.force-ssl`)
   - Click **"Update"** → **"Save and Continue"**
6. **Test users** page (CRITICAL — skipping this causes "Access blocked" error):
   - Click **"Add Users"**
   - Add the **exact Google email** you'll use to sign in (e.g., `your-email@gmail.com`)
   - Click **"Save and Continue"**
   - ⚠️ If you already skipped this step and got "Access blocked": Go to **OAuth consent screen** → **Audience** tab → **Add Users** → add your email
7. Click **"Back to Dashboard"**

### Step 4: Create OAuth2 Credentials
1. Go to **APIs & Services** → **Credentials**
2. Click **"+ Create Credentials"** → **"OAuth client ID"**
3. Application type: **Web application**
4. Name: `n8n`
5. Under **"Authorized redirect URIs"**:
   - Click **"+ Add URI"**
   - Enter: `http://localhost:5678/rest/oauth2-credential/callback`
6. Click **"Create"**
7. Copy **Client ID** and **Client Secret** from the popup

### Step 5: Add Credential to n8n
1. Open your imported workflow in n8n
2. Click on the **"Upload to YouTube"** node
3. Click **"Credential to connect with"** → **"Create New Credential"**
4. Select **"YouTube OAuth2 API"**
5. Paste:
   - **Client ID**: from step 4
   - **Client Secret**: from step 4
6. Click **"Sign in with Google"**
7. Select your YouTube channel's Google account
8. If you see "This app isn't verified" warning:
   - Click **"Advanced"** → **"Go to n8n YouTube (unsafe)"**
   - This is safe — it's your own app
9. Click **"Allow"** for all requested permissions
10. You should see **"Connected"** in n8n
11. Click **"Save"**

### YouTube API Quotas
- Daily quota: 10,000 units
- Video upload: 1,600 units per upload
- Maximum ~6 uploads per day within free quota
- Quota resets at midnight Pacific Time

### OAuth Token Refresh
- Tokens expire periodically
- n8n auto-refreshes them, but if upload fails with auth error:
  - Go to the YouTube credential in n8n
  - Click **"Sign in with Google"** again to re-authorize

---

## Playlist Setup (Optional)

The workflow includes an **"Add to Playlist"** node that automatically adds each uploaded video to a YouTube playlist.

### Get Your Playlist ID
1. Open YouTube and go to the playlist you want videos added to (or create a new one)
2. The URL will look like: `https://www.youtube.com/playlist?list=PLxxxxxxxxxxxxxxxxxx`
3. Copy the part after `list=` — that's your playlist ID (starts with `PL`)

### Configure in n8n
1. Click on the **"Add to Playlist"** node
2. Replace `YOUR_PLAYLIST_ID` with your actual playlist ID
3. Make sure the **YouTube OAuth2** credential is assigned (same credential as the Upload to YouTube node)
4. Click **"Save"**

### Skip Playlist
If you don't want videos added to a playlist:
- Delete the **"Add to Playlist"** node
- Connect **"Upload to YouTube"** directly to **"Success Output"**

---

## Post-Setup: First Test Run

### Before running, change to unlisted
1. Open workflow
2. Click **"Upload to YouTube"** node
3. Change `privacyStatus` from `public` to `unlisted`
4. Save

### Run the workflow
1. Click **"Test Workflow"** (play button in top-right)
2. Wait 8-12 minutes for full execution
3. Watch the execution progress — each node lights up green when done

### Verify
- [ ] Reddit and HN data were fetched successfully
- [ ] GPT-5 picked a story and generated a script with ~90 words
- [ ] 4 vertical image URLs were generated by DALL-E 3
- [ ] Voiceover audio was created
- [ ] Video was composed by Creatomate (render status: succeeded)
- [ ] Video appeared in your YouTube Studio as unlisted
- [ ] Video was added to your playlist (if configured)

### Switch to public
Once verified, change `privacyStatus` back to `public` for future runs.

---

## Credential Summary

| # | Credential | Type | Nodes Using It | Cost |
|---|---|---|---|---|
| 1 | OpenAI API | API Key | Script Gen (GPT-5) | ~$0.04/video |
| 2 | Header Auth (OpenAI) | Header Auth | DALL-E 3, Voiceover (TTS) | ~$0.16/video |
| 3 | Header Auth (Creatomate) | Header Auth | Compose Video, Check Render | Free (10/month) |
| 4 | YouTube OAuth2 | OAuth2 | Upload to YouTube, Add to Playlist | Free |

---

## Troubleshooting

### "Invalid API key" on OpenAI nodes
- Verify the key at platform.openai.com → API Keys
- Check you have billing credits remaining
- Make sure you're using the API key, not the ChatGPT session token

### "Unauthorized" on Creatomate
- Check Header Auth value is exactly: `Bearer your-key` (with space after Bearer)
- Verify the API key in Creatomate dashboard

### "OAuth token expired" on YouTube
- Go to the credential in n8n → click "Sign in with Google" again
- Make sure you added yourself as a test user in Google Cloud Console

### "Redirect URI mismatch" on YouTube OAuth
- In Google Cloud Console → Credentials → edit your OAuth client
- Make sure the redirect URI is exactly: `http://localhost:5678/rest/oauth2-credential/callback`
- No trailing slash, no https (it's localhost)

### "Access blocked: n8n YouTube has not completed Google verification"
- **Most common cause**: You didn't add yourself as a test user
- **Fix**: Google Cloud Console → **APIs & Services** → **OAuth consent screen** → **Audience** tab → **Add Users** → add your exact Google email
- After adding, go back to n8n and click **"Sign in with Google"** again

### "This app isn't verified" warning (different from above)
- This is normal for test/unverified apps — your app works fine
- Click **"Advanced"** → **"Go to n8n YouTube (unsafe)"**
- This is safe — it's your own app, not a third party

### "Quota exceeded" on YouTube
- Free quota: 10,000 units/day, upload = 1,600 units
- Wait until midnight Pacific Time for quota reset
- Or request a quota increase in Google Cloud Console

---

## Migrating to a Different n8n Instance

### Method 1: Export/Import via n8n UI (Easiest)

**Export from current instance:**
1. Open your workflow in n8n
2. Click the **three dots menu (⋮)** in the top-right → **"Download"**
3. This saves a `.json` file with the complete workflow (nodes, connections, settings)
4. Credentials are **NOT included** in the export (for security)

**Import to new instance:**
1. Open the new n8n instance
2. Click **"Add workflow"** (or **"Import from file"** on the workflows page)
3. Select the downloaded `.json` file
4. The workflow will appear with all nodes and connections intact
5. **Re-configure all 4 credentials** on the new instance (see credential setup sections above)
6. Update the Creatomate template ID if using a different Creatomate account

### Method 2: n8n API (Programmatic)

**Export via API:**
```bash
# Export workflow JSON from current instance
curl -H "X-N8N-API-KEY: $N8N_API_KEY" \
  http://localhost:5678/api/v1/workflows/YOUR_WORKFLOW_ID \
  -o youtube-shorts-workflow.json
```

**Import via API:**
```bash
# Import to new instance
curl -X POST \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @youtube-shorts-workflow.json \
  http://your-n8n-url:5678/api/v1/workflows
```

### Method 3: Recreate with Claude Code + MCP

If you have Claude Code with the n8n MCP server configured on the new instance:
1. Share the `docs/workflow-reference.md` file with Claude
2. Ask Claude to recreate the workflow using `n8n_create_workflow`
3. Claude can rebuild the entire 18-node workflow from the documentation
4. This is the power of having the workflow fully documented in markdown

### Method 4: n8n Cloud Migration

If migrating from Docker to n8n Cloud:
1. Export the workflow JSON from Docker instance (Method 1 or 2)
2. Sign up at [app.n8n.cloud](https://app.n8n.cloud)
3. Import the workflow JSON
4. Re-configure credentials (Cloud has built-in OAuth handling — easier setup)
5. Replace **Manual Trigger** with **Schedule Trigger** for daily automation:
   - Edit the first node → change type to Schedule Trigger
   - Set cron: `0 9 * * *` (daily at 9 AM)
6. Activate the workflow

### After Migration Checklist

On the new instance, you must:
- [ ] Create and assign **OpenAI API** credential (API key)
- [ ] Create and assign **HTTP Header Auth** for TTS (`Authorization: Bearer sk-...`)
- [ ] Create and assign **HTTP Header Auth** for Creatomate (`Authorization: Bearer cm-...`)
- [ ] Create and assign **YouTube OAuth2** credential (new OAuth2 client or reuse existing)
- [ ] Update **Creatomate template ID** in the "Compose Video" node (if using a different account)
- [ ] Update **playlist ID** in the "Add to Playlist" node (or remove the node if not needed)
- [ ] Update the **YouTube OAuth2 redirect URI** to match the new instance URL
  - Docker: `http://localhost:5678/rest/oauth2-credential/callback`
  - Cloud: `https://your-instance.app.n8n.cloud/rest/oauth2-credential/callback`
- [ ] Test with `privacyStatus: "unlisted"` before going public
- [ ] Verify all nodes execute successfully end-to-end
