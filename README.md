# Crush Block

`Crush Block` is a 1:1 turn-based strategy board game on a 9x9 board.

Supabase is used for auth, user data, rankings, coins, skins, and match result persistence. Realtime gameplay is handled by the authoritative Node.js + Socket.io server in `game_server`.

## Game Server

```sh
cd game_server
npm install
npm start
```

The Flutter client connects to `http://localhost:3001` by default.

Optional server environment variables for match result persistence:

```sh
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
```

Apply `supabase/crush_block_match_results.sql` before enabling result persistence.

## Flutter App

Create `.env` with your Supabase client values:

```sh
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
```

Then run:

```sh
flutter pub get
flutter run
```
# crush_block
