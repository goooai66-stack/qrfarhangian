#!/usr/bin/env bash
# نصب سرور کالری‌لنز روی یک سرور لینوکسی (Ubuntu/Debian) با Docker.
#   git clone <repo> && cd <repo> && bash deploy/install.sh api.example.ir
# پیش‌نیاز: رکورد DNS دامنه به IP همین سرور اشاره کند و پورت‌های 80 و 443 باز باشند.
set -euo pipefail
cd "$(dirname "$0")"

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  read -r -p "دامنه‌ی سرور (مثل api.example.ir): " DOMAIN
fi
if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]]; then
  echo "دامنه نامعتبر است: $DOMAIN" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker نصب نیست. نصب: https://docs.docker.com/engine/install/" >&2
  exit 1
fi

if [ -f .env ]; then
  echo ".env از قبل هست؛ دست نمی‌خورد (کد راه‌اندازی قبلی معتبر می‌ماند)."
  sed -i "s/^DOMAIN=.*/DOMAIN=$DOMAIN/" .env
else
  TOKEN="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  umask 077
  cat > .env <<ENV
DOMAIN=$DOMAIN
APP_ENV=production
# کد راه‌اندازی پنل مدیریت (یک بار، برای ساخت رمز مدیر)
ADMIN_TOKEN=$TOKEN
# کلید و مدل هوش مصنوعی از پنل مدیریت وارد می‌شود، نه اینجا.
VISION_PROVIDER=none
PURCHASE_VERIFIER=stores
REWARD_VERIFIER=disabled
ENV
fi

docker compose up -d --build

TOKEN="$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)"
cat <<MSG

سرور بالا آمد.

  آدرس سرور برای اپ:   https://$DOMAIN
  پنل مدیریت:          https://$DOMAIN/admin
  کد راه‌اندازی مدیر:   $TOKEN

قدم بعد: پنل مدیریت را باز کن، با کد بالا رمز خودت را بساز، بعد کلید و مدل
هوش مصنوعی را وارد کن و «آزمایش اتصال به مدل» را بزن.
کد راه‌اندازی را جای امن نگه دار و به کسی نده.
پشتیبان‌گیری داده‌ها: docker compose cp api:/data/calorielens.db ./backup.db
MSG
