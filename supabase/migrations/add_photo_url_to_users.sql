-- Add photo_url column to all user tables
ALTER TABLE users_adm ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE users_personal ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE users_nutricionista ADD COLUMN IF NOT EXISTS photo_url TEXT;
ALTER TABLE users_alunos ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- Create 'profiles' bucket having public access
-- Note: This requires the storage schema to be active
INSERT INTO storage.buckets (id, name, public)
VALUES ('profiles', 'profiles', true)
ON CONFLICT (id) DO NOTHING;

-- Policy: Give public read access to everyone
DROP POLICY IF EXISTS "Public Profiles Access" ON storage.objects;
CREATE POLICY "Public Profiles Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'profiles' );

-- Policy: Allow authenticated users to upload
DROP POLICY IF EXISTS "Authenticated users can upload profiles" ON storage.objects;
CREATE POLICY "Authenticated users can upload profiles"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'profiles' AND auth.role() = 'authenticated' );

-- Policy: Allow authenticated users to update
DROP POLICY IF EXISTS "Authenticated users can update profiles" ON storage.objects;
CREATE POLICY "Authenticated users can update profiles"
ON storage.objects FOR UPDATE
USING ( bucket_id = 'profiles' AND auth.role() = 'authenticated' );
