# Remove Ads (one-time purchase)

One in-app product, bought once and kept for good on the player's Google account:
**Remove Ads, $3.99** (`remove_ads`, a one-time, non-consumable product in Play Console).

## What the player gets
| Ad | After buying |
|----|--------------|
| Interstitial between levels | **Gone** |
| Journey map banner | **Gone** (disappears the moment the purchase completes) |
| Rewarded videos (extra hint, shuffle, undo, second chance) | **Stay, optional.** The player chooses them; nothing is forced |

The store text and the in-game wording say exactly this ("Reward videos for extra hints stay
optional"), so nobody pays expecting something else. Play's refund window applies as usual.

## Where it is offered
1. **Settings** (start screen and pause): a "Remove Ads · $3.99" button and "Restore Purchase".
   After buying, the row shows a thank-you instead; while a payment is pending it says so.
2. **A rare suggestion on the journey map**, never during play:
   - only after the player has seen 3 ads between levels since the last suggestion;
   - at most once a week, and never more than 3 times in total;
   - never together with the reminder question, and never once bought or pending.
   - Buttons: "Remove Ads · $3.99" and "Not Now". Android back = Not Now.

The price always comes from Google Play (`ProductDetails`), so each country sees its own local
price and currency. Nothing is offered until Play has answered with a price.

## Workflow
```
launch ──► saved state (ads off if bought before, works offline)
        └► connect to Play ──► price for remove_ads
                            └► list this account's purchases ──► grant / refund / pending
tap Remove Ads ──► Play's purchase sheet ──► result
    OK + PURCHASED ──► ads off at once, saved, acknowledged, "Thank You!"
    OK + PENDING   ──► nothing unlocked yet, "Payment Pending" (unlocks when Play confirms,
                       in this session or on a later launch)
    Cancelled      ──► nothing said
    Already owned  ──► restore from Play's list ("Purchase Restored")
    Other error    ──► "Purchase Not Completed … nothing was charged"
Restore Purchase ──► Play's list again ──► Restored / All Set / Nothing to Restore / Store Unavailable
```
Rules (`PurchaseRules`, unit-tested):
- **Play is the truth.** Each launch asks Play what the account owns. A reinstall or a new phone
  restores the purchase by itself; a refund takes it away. Only a *successful* answer can take it
  away; a failed or offline query never does.
- **Only PURCHASED unlocks.** PENDING (cash payments, slow cards) unlocks nothing until it completes.
- **Acknowledge every completed purchase.** Play refunds unacknowledged purchases after 3 days. A
  failed acknowledgement is retried on the next launch (the purchase is listed unacknowledged).
- **Saved state** (`settings.cfg`, section `purchases`) is only a cache of Play's last answer, so an
  offline phone keeps its ads off.

## Code
| Part | File |
|------|------|
| Rules (pure, unit-tested) | `scripts/core/purchase_rules.gd` |
| Autoload `Purchases` (state, dialogs, suggestion) | `scripts/autoload/purchases.gd` |
| Bridge to the plugin (or a test fake) | `scripts/purchases/play_billing_bridge.gd` |
| Android plugin "ZenPlayBilling" (Play Billing Library 8.0.0) | `android_plugins/play_billing/src/`, built to `addons/zen_play_billing/bin/` by `bash android_plugins/play_billing/build.sh` |
| Ads switch | `AdsManager.set_ads_removed()` (interstitials and banner only) |
| Settings row | `PurchaseRow` in `scenes/components/audio_settings.tscn` |
| Tests | `tests/unit/test_purchase_rules.gd`, `tests/integration/purchases_test.tscn` |

No server: purchases are checked on the phone. That is normal for a small ad-removal product; a
server check (Play Developer API) would only be worth it for valuable items.
Desktop and web builds sell nothing (no plugin), and the iOS App Store would need StoreKit.

## Play Console setup (your side)
1. **Payments profile**: Play Console → Settings → Payments profile (merchant account, bank, tax).
2. **Upload a build with billing** (1.0.13 or later) to Closed testing. Play only lets you create
   products after it has seen an app with the BILLING permission.
3. **Create the product**: Monetize with Play → Products → One-time products → Create:
   - Product ID **`remove_ads`** (exactly; ids can never be reused or changed)
   - Name "Remove Ads", description "Removes the ads between levels and on the map. Reward videos
     stay optional."
   - Price **USD 3.99** (Play fills in local prices), then **Activate**.
4. **Licence testers**: Settings → License testing → add the testers' Google accounts. Their
   purchases use test cards ("Test card, always approves", "…slow test card" for pending) and are
   never charged. Test from a build installed from the testing track.
5. **Store listing**: Play shows "In-app purchases" automatically. Data safety: purchases are handled
   by Google Play; the game itself stores only "bought: yes/no" on the phone.
6. **Refund test**: Order management → refund the test order → the next launch shows ads again.
