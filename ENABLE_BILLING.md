# Enable Billing on Google Cloud

The error you're seeing means billing needs to be enabled for your Google Cloud project before you can use certain services.

## Step 1: Enable Billing

### Option A: Via Google Cloud Console (Recommended)

1. **Go to the Billing page:**
   - Visit: https://console.cloud.google.com/billing
   - Or navigate: Cloud Console → Billing

2. **Link a billing account:**
   - If you don't have a billing account, click "Create Billing Account"
   - Enter your payment information (credit card)
   - Google provides $300 free credit for new accounts!

3. **Link to your project:**
   - Go to: https://console.cloud.google.com/billing/projects
   - Find your project (ID: 54081323840 or name: lunareading-app)
   - Click "Change billing account"
   - Select your billing account
   - Click "Set account"

### Option B: Via gcloud CLI

```bash
# List available billing accounts
gcloud billing accounts list

# Link billing account to project
gcloud billing projects link 54081323840 --billing-account=BILLING_ACCOUNT_ID
```

Replace `BILLING_ACCOUNT_ID` with your billing account ID from the list.

## Step 2: Verify Billing is Enabled

```bash
# Check billing status
gcloud billing projects describe 54081323840
```

You should see `billingAccountName` in the output.

## Step 3: Retry Enabling APIs

Once billing is enabled, retry the command:

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

Or if using artifactregistry:

```bash
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

## Free Tier Information

**Good news!** Google Cloud provides:
- **$300 free credit** for new accounts (valid for 90 days)
- **Cloud Run free tier**: 2 million requests/month free
- **Container Registry**: Free storage for first 0.5 GB
- **Cloud Build**: 120 build-minutes/day free

For a small application like LunaReading, you'll likely stay within the free tier!

## Cost Estimates

Even after free tier:
- **Cloud Run**: ~$0.40 per million requests (very cheap)
- **Container Registry**: ~$0.026/GB/month
- **Estimated monthly cost**: $0-5 for low-medium traffic

## Troubleshooting

### If you don't see "Create Billing Account" option:
- Make sure you're signed in with a Google account that has permission
- Try a different browser or incognito mode
- Check if your organization has restrictions

### If billing account creation fails:
- Ensure your payment method is valid
- Check if there are any restrictions on your Google account
- Contact Google Cloud support if issues persist

## Next Steps

After enabling billing:
1. ✅ Retry enabling the APIs
2. ✅ Continue with deployment: `./deploy.sh`
3. ✅ Monitor usage in Cloud Console to stay within free tier

