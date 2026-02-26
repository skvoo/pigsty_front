/**
 * Count objects in MinIO buckets (GD-lounge, imperial). No Supabase needed.
 * Usage: set MINIO_ENDPOINT, MINIO_ACCESS_KEY, MINIO_SECRET_KEY for one user, then run for each bucket.
 * Or run from repo with: node check_minio_buckets.js (reads same .env or use defaults for endpoint).
 */
const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');

const MINIO_ENDPOINT = process.env.MINIO_ENDPOINT || 'http://104.223.25.234:9000';

const buckets = [
  { name: 'gd-lounge-assets', accessKey: process.env.MINIO_GDLOUNGE_ACCESS_KEY || 's3user_gdlounge', secretKey: process.env.MINIO_GDLOUNGE_SECRET_KEY || 'GdLoungeStorage7xKp2mNqR' },
  { name: 'imperial-event-images', accessKey: 's3user_imperial_ev', secretKey: 'ImperialStorage7xKp2mNqR' },
  { name: 'imperial-furniture-images', accessKey: 's3user_imperial_fu', secretKey: 'ImperialStorage7xKp2mNqR' },
  { name: 'imperial-news-images', accessKey: 's3user_imperial_nw', secretKey: 'ImperialStorage7xKp2mNqR' },
  { name: 'imperial-product-images', accessKey: 's3user_imperial_pr', secretKey: 'ImperialStorage7xKp2mNqR' },
  { name: 'imperial-site-images', accessKey: 's3user_imperial_si', secretKey: 'ImperialStorage7xKp2mNqR' },
];

async function countBucket(s3, bucketName) {
  let count = 0;
  let token;
  do {
    const cmd = new ListObjectsV2Command({ Bucket: bucketName, MaxKeys: 1000, ContinuationToken: token });
    const out = await s3.send(cmd);
    count += (out.Contents || []).length;
    token = out.NextContinuationToken;
  } while (token);
  return count;
}

async function main() {
  for (const b of buckets) {
    const s3 = new S3Client({
      region: 'us-east-1',
      endpoint: MINIO_ENDPOINT,
      forcePathStyle: true,
      credentials: { accessKeyId: b.accessKey, secretAccessKey: b.secretKey },
    });
    try {
      const n = await countBucket(s3, b.name);
      console.log(`${b.name}: ${n} objects`);
    } catch (e) {
      console.log(`${b.name}: error - ${e.message}`);
    }
  }
}

main().catch(console.error);
