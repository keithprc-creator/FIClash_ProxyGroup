#!/bin/bash
# setup_qoder_proxy_group.sh
# Creates a "Qoder" proxy group in FIClash that routes Qoder/QoderWork/qodercli
# traffic to DIRECT by default, with Asian (JP/TW/SG) nodes available for manual switching.
#
# Usage: ./setup_qoder_proxy_group.sh
# Prerequisites: FIClash running, Clash API on port 9090

set -euo pipefail

DB="$HOME/Library/Application Support/com.follow.clash/database.sqlite"
CONFIG="$HOME/Library/Application Support/com.follow.clash/config.yaml"
API="http://127.0.0.1:9090"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=== FIClash Qoder Proxy Group Setup ==="

# Check prerequisites
if [ ! -f "$DB" ]; then
  echo -e "${RED}Error: FIClash database not found at $DB${NC}"
  exit 1
fi

if ! curl -s "$API/version" > /dev/null 2>&1; then
  echo -e "${RED}Error: Clash API not reachable at $API${NC}"
  echo "Make sure FIClash is running with External Controller enabled on port 9090"
  exit 1
fi

echo -e "${GREEN}✓ FIClash database found${NC}"
echo -e "${GREEN}✓ Clash API reachable$(curl -s $API/version | python3 -c "import json,sys;print(' ('+json.load(sys.stdin)['version']+')')")${NC}"

# Get profile ID
PROFILE_ID=$(sqlite3 "$DB" "SELECT id FROM profiles LIMIT 1;")
if [ -z "$PROFILE_ID" ]; then
  echo -e "${RED}Error: No profile found in database${NC}"
  exit 1
fi
echo "Profile ID: $PROFILE_ID"

# Check if Qoder group already exists
EXISTING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM proxy_groups WHERE name='Qoder' AND profile_id=$PROFILE_ID;")
if [ "$EXISTING" -gt 0 ]; then
  echo "Qoder proxy group already exists in database. Skipping insert."
else
  # Backup database
  cp "$DB" "$DB.bak.$(date +%Y%m%d%H%M%S)"
  echo -e "${GREEN}✓ Database backed up${NC}"

  # Insert proxy group
  sqlite3 "$DB" "
  INSERT INTO proxy_groups (profile_id, name, type, proxies, include_all_proxies, filter, \"order\")
  VALUES ($PROFILE_ID, 'Qoder', 'select', '[\"DIRECT\"]', 1, '(?i)(JP|TW|SG|HK)', 'a0');
  "
  echo -e "${GREEN}✓ Qoder proxy group inserted${NC}"

  # Insert rules
  sqlite3 "$DB" "
  INSERT INTO rules (rule_action, content, rule_target, no_resolve, src)
  VALUES ('PROCESS-NAME', 'Qoder', 'Qoder', 0, 0);
  INSERT INTO rules (rule_action, content, rule_target, no_resolve, src)
  VALUES ('PROCESS-NAME', 'QoderWork', 'Qoder', 0, 0);
  INSERT INTO rules (rule_action, content, rule_target, no_resolve, src)
  VALUES ('PROCESS-NAME', 'qodercli', 'Qoder', 0, 0);
  "
  echo -e "${GREEN}✓ PROCESS-NAME rules inserted${NC}"

  # Map rules to profile
  sqlite3 "$DB" "
  INSERT INTO profile_rule_mapping (id, profile_id, rule_id, scene, \"order\")
  SELECT 'qoder-rule-' || id, $PROFILE_ID, id, 'prepend', 'a' || (id - 1)
  FROM rules WHERE rule_target = 'Qoder'
  AND id NOT IN (SELECT rule_id FROM profile_rule_mapping);
  "
  echo -e "${GREEN}✓ Rules mapped to profile (prepend)${NC}"
fi

# Now apply to running config
echo ""
echo "Applying to running Clash instance..."

# Reload config
curl -s -X PUT "$API/configs?force=true" \
  -H "Content-Type: application/json" \
  -d "{\"path\": \"$CONFIG\"}"

sleep 1

# Verify
if curl -s "$API/proxies/Qoder" | python3 -c "import json,sys;d=json.load(sys.stdin);assert d['name']=='Qoder'" 2>/dev/null; then
  echo -e "${GREEN}✓ Qoder proxy group is active!${NC}"
  echo ""
  echo "Current selection: $(curl -s $API/proxies/Qoder | python3 -c "import json,sys;print(json.load(sys.stdin)['now'])")"
  echo "Available proxies: $(curl -s $API/proxies/Qoder | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(d['all']))")"
else
  echo -e "${RED}Warning: Qoder group not found in running config.${NC}"
  echo "The database override is saved. Try restarting FIClash or manually editing config.yaml."
fi

echo ""
echo "Done! Use 'curl -X PUT $API/proxies/Qoder -d '{\"name\":\"JP-X5-1\"}'' to switch nodes."
