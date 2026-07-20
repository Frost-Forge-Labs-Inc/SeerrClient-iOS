# SeerrClient

A free, open-source native iOS app for managing media requests on your self-hosted [Jellyseerr](https://github.com/Jellyseerr/jellyseerr), [Overseerr](https://github.com/sct/overseerr), or [Seerr](https://github.com/seerr-team/seerr) server.

**Documentation:** [seerrclient.dev](https://seerrclient.dev)
**Built by:** [Frost Forge Labs Inc.](https://frostforgelabs.ca)
**License:** Apache 2.0

---

## Why we built it

SeerrClient started as a personal hobby project. We run our own home media servers and wanted a proper native iOS experience for managing requests — the kind that feels at home on iPhone and iPad rather than a browser wrapper. We figured plenty of people in the home server community felt the same way, so we open-sourced it under Apache 2.0 and built it out properly.

If you love self-hosted media, this was made for you.

---

## Features

- **Multi-server** — add and switch between multiple Jellyseerr, Overseerr, or Seerr instances
- **Authentication** — local login, Plex OAuth, and Jellyfin/Emby credentials
- **Remember Me** — persistent session restore via Keychain; explicit logout clears all credentials
- **Discover** — curated media sliders driven by your server configuration
- **Search** — instant search across movies, TV shows, and people with type filters
- **Requests** — create movie and TV requests; select seasons; choose Radarr/Sonarr quality profiles
- **Collections** — request individual movies from a collection or all at once
- **Admin controls** — approve, decline, and delete requests; swipe actions
- **Watchlist** — sync and browse your Jellyfin watchlist (Jellyseerr/Seerr)
- **Themes** — system, light, and dark appearance modes
- **Self-signed certificates** — TOFU trust model for home network HTTPS

**Supported backends:** Jellyseerr · Overseerr · Seerr
**Requirements:** iOS 18+ · iPhone or iPad

---

## Getting Started

See [seerrclient.dev/docs/getting-started](https://seerrclient.dev/docs/getting-started/) for installation, server setup, and sign-in guides.

---

## Contributing

Bug reports and pull requests are welcome. Please open an issue before submitting a large change.

---

## Disclaimer & Responsible Use

SeerrClient is a client interface for media request management software. **It does not host, stream, index, or distribute any media content.**

You are solely responsible for ensuring that your use of this software, and any content you request or manage through it, complies with all applicable laws, regulations, and the terms of service of any third-party services you connect to — including your media server software and any content sources it uses.

Frost Forge Labs Inc. makes no warranties regarding the suitability of this software for any particular purpose and accepts no liability for how it is used or what content is managed through it.

SeerrClient is an independent third-party client and is **not affiliated with, endorsed by, or supported by** the Seerr, Jellyseerr, Overseerr, Plex, Jellyfin, Emby, or TMDB projects or their respective teams.

---

## License

[Apache License 2.0](LICENSE) — see [NOTICE](NOTICE) for third-party attributions.
