package org.zenmahjong.playbilling;

import android.app.Activity;

import com.android.billingclient.api.AcknowledgePurchaseParams;
import com.android.billingclient.api.BillingClient;
import com.android.billingclient.api.BillingClientStateListener;
import com.android.billingclient.api.BillingFlowParams;
import com.android.billingclient.api.BillingResult;
import com.android.billingclient.api.PendingPurchasesParams;
import com.android.billingclient.api.ProductDetails;
import com.android.billingclient.api.Purchase;
import com.android.billingclient.api.PurchasesUpdatedListener;
import com.android.billingclient.api.QueryProductDetailsParams;
import com.android.billingclient.api.QueryPurchasesParams;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONObject;

import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Google Play Billing for one-time products (the game's "Remove Ads"), as the
 * Godot singleton "ZenPlayBilling". Purchases reach Godot as JSON text:
 * [{"products": [...], "state": 1, "token": "...", "acknowledged": false}].
 * The game decides what a purchase unlocks and when to acknowledge it.
 */
public class PlayBillingPlugin extends GodotPlugin implements PurchasesUpdatedListener {
	private BillingClient client;
	private final Map<String, ProductDetails> details = new HashMap<>();

	public PlayBillingPlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "ZenPlayBilling";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(new SignalInfo("connected"));
		signals.add(new SignalInfo("connect_failed", Integer.class, String.class));
		signals.add(new SignalInfo("product_found", String.class, String.class, String.class));
		signals.add(new SignalInfo("product_missing", String.class, Integer.class));
		signals.add(new SignalInfo("purchases_listed", String.class));
		signals.add(new SignalInfo("purchases_failed", Integer.class));
		signals.add(new SignalInfo("purchase_updated", Integer.class, String.class));
		signals.add(new SignalInfo("acknowledged", String.class, Integer.class));
		return signals;
	}

	/** Connects to Play (again, if needed): "connected" or "connect_failed". */
	@UsedByGodot
	public void startConnection() {
		final Activity activity = getActivity();
		if (activity == null) {
			emitSignal("connect_failed", BillingClient.BillingResponseCode.ERROR, "no activity");
			return;
		}
		activity.runOnUiThread(() -> {
			if (client == null) {
				client = BillingClient.newBuilder(activity)
						.setListener(this)
						.enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
						.enableAutoServiceReconnection()
						.build();
			}
			if (client.isReady()) {
				emitSignal("connected");
				return;
			}
			client.startConnection(new BillingClientStateListener() {
				@Override
				public void onBillingSetupFinished(BillingResult result) {
					if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
						emitSignal("connected");
					} else {
						emitSignal("connect_failed", result.getResponseCode(), result.getDebugMessage());
					}
				}

				@Override
				public void onBillingServiceDisconnected() {
					// Auto reconnection retries on the next call.
				}
			});
		});
	}

	/** Looks up a one-time product: "product_found" (with Play's local price) or "product_missing". */
	@UsedByGodot
	public void queryProduct(final String productId) {
		if (!ready()) {
			emitSignal("product_missing", productId, BillingClient.BillingResponseCode.SERVICE_DISCONNECTED);
			return;
		}
		QueryProductDetailsParams params = QueryProductDetailsParams.newBuilder()
				.setProductList(Collections.singletonList(QueryProductDetailsParams.Product.newBuilder()
						.setProductId(productId)
						.setProductType(BillingClient.ProductType.INAPP)
						.build()))
				.build();
		client.queryProductDetailsAsync(params, (result, found) -> {
			List<ProductDetails> list = found.getProductDetailsList();
			for (ProductDetails product : list) {
				if (product.getProductId().equals(productId) && product.getOneTimePurchaseOfferDetails() != null) {
					details.put(productId, product);
					emitSignal("product_found", productId,
							product.getOneTimePurchaseOfferDetails().getFormattedPrice(), product.getName());
					return;
				}
			}
			int code = result.getResponseCode();
			emitSignal("product_missing", productId,
					code == BillingClient.BillingResponseCode.OK ? BillingClient.BillingResponseCode.ITEM_UNAVAILABLE : code);
		});
	}

	/** Every one-time purchase this Google account owns or has pending: "purchases_listed". */
	@UsedByGodot
	public void queryPurchases() {
		if (!ready()) {
			emitSignal("purchases_failed", BillingClient.BillingResponseCode.SERVICE_DISCONNECTED);
			return;
		}
		client.queryPurchasesAsync(
				QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
				(result, purchases) -> {
					if (result.getResponseCode() == BillingClient.BillingResponseCode.OK) {
						emitSignal("purchases_listed", toJson(purchases));
					} else {
						emitSignal("purchases_failed", result.getResponseCode());
					}
				});
	}

	/** Opens Play's purchase sheet. The outcome arrives as "purchase_updated". */
	@UsedByGodot
	public void purchase(final String productId) {
		final Activity activity = getActivity();
		final ProductDetails product = details.get(productId);
		if (activity == null || product == null || !ready()) {
			emitSignal("purchase_updated", BillingClient.BillingResponseCode.ITEM_UNAVAILABLE, "[]");
			return;
		}
		activity.runOnUiThread(() -> {
			BillingFlowParams params = BillingFlowParams.newBuilder()
					.setProductDetailsParamsList(Collections.singletonList(
							BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(product).build()))
					.build();
			BillingResult result = client.launchBillingFlow(activity, params);
			if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
				emitSignal("purchase_updated", result.getResponseCode(), "[]");
			}
		});
	}

	/** Confirms a purchase to Play (unacknowledged purchases are refunded after 3 days). */
	@UsedByGodot
	public void acknowledge(final String token) {
		if (!ready()) {
			emitSignal("acknowledged", token, BillingClient.BillingResponseCode.SERVICE_DISCONNECTED);
			return;
		}
		client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build(),
				result -> emitSignal("acknowledged", token, result.getResponseCode()));
	}

	@Override
	public void onPurchasesUpdated(BillingResult result, List<Purchase> purchases) {
		emitSignal("purchase_updated", result.getResponseCode(), toJson(purchases));
	}

	@Override
	public void onMainDestroy() {
		if (client != null) {
			client.endConnection();
			client = null;
		}
	}

	private boolean ready() {
		return client != null && client.isReady();
	}

	private static String toJson(List<Purchase> purchases) {
		JSONArray list = new JSONArray();
		if (purchases == null) {
			return list.toString();
		}
		for (Purchase purchase : purchases) {
			try {
				JSONObject entry = new JSONObject();
				entry.put("products", new JSONArray(purchase.getProducts()));
				entry.put("state", purchase.getPurchaseState());
				entry.put("token", purchase.getPurchaseToken());
				entry.put("acknowledged", purchase.isAcknowledged());
				list.put(entry);
			} catch (Exception ignored) {
				// A purchase that cannot be described is left out; the next query lists it again.
			}
		}
		return list.toString();
	}
}
