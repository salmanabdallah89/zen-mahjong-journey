package org.zenmahjong.playupdate;

import android.app.Activity;

import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.InstallState;
import com.google.android.play.core.install.InstallStateUpdatedListener;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.InstallStatus;
import com.google.android.play.core.install.model.UpdateAvailability;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Google Play In-App Updates for Zen Mahjong Journey (scripts/updates/play_update_bridge.gd).
 * Asks Play whether this install has an update, starts Play's flexible (background) or
 * immediate flow, reports download progress and installs a downloaded update on request.
 * Play decides availability per player and track, so nothing else has to be published.
 */
public class PlayUpdatePlugin extends GodotPlugin {
	private static final SignalInfo UPDATE_CHECKED = new SignalInfo("update_checked",
			Boolean.class, Boolean.class, Boolean.class, Integer.class, Integer.class);
	private static final SignalInfo CHECK_FAILED = new SignalInfo("check_failed", String.class);
	private static final SignalInfo INSTALL_STATUS = new SignalInfo("install_status",
			Integer.class, Long.class, Long.class);
	private static final SignalInfo FLOW_RESULT = new SignalInfo("flow_result", Integer.class);

	private AppUpdateManager manager;
	private AppUpdateInfo lastInfo;
	private boolean listening = false;

	private final InstallStateUpdatedListener listener = new InstallStateUpdatedListener() {
		@Override
		public void onStateUpdate(InstallState state) {
			emitSignal(INSTALL_STATUS.getName(), state.installStatus(), state.bytesDownloaded(),
					state.totalBytesToDownload());
			int status = state.installStatus();
			if (status == InstallStatus.INSTALLED || status == InstallStatus.FAILED
					|| status == InstallStatus.CANCELED) {
				stopListening();
			}
		}
	};

	public PlayUpdatePlugin(Godot godot) {
		super(godot);
	}

	@Override
	public String getPluginName() {
		return "ZenPlayUpdate";
	}

	@Override
	public Set<SignalInfo> getPluginSignals() {
		Set<SignalInfo> signals = new HashSet<>();
		signals.add(UPDATE_CHECKED);
		signals.add(CHECK_FAILED);
		signals.add(INSTALL_STATUS);
		signals.add(FLOW_RESULT);
		return signals;
	}

	private AppUpdateManager manager() {
		if (manager == null) {
			manager = AppUpdateManagerFactory.create(getContext());
		}
		return manager;
	}

	/**
	 * Emits update_checked(available, flexible_allowed, immediate_allowed, version_code,
	 * staleness_days), or check_failed. A downloaded flexible update also emits
	 * install_status(DOWNLOADED), so the game can offer the restart again.
	 */
	@UsedByGodot
	public void checkForUpdate() {
		manager().getAppUpdateInfo()
				.addOnSuccessListener(info -> {
					lastInfo = info;
					int availability = info.updateAvailability();
					boolean available = availability == UpdateAvailability.UPDATE_AVAILABLE;
					Integer staleness = info.clientVersionStalenessDays();
					emitSignal(UPDATE_CHECKED.getName(), available,
							info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
							info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
							info.availableVersionCode(), staleness == null ? -1 : staleness);
					if (info.installStatus() == InstallStatus.DOWNLOADED) {
						emitSignal(INSTALL_STATUS.getName(), InstallStatus.DOWNLOADED,
								info.bytesDownloaded(), info.totalBytesToDownload());
					}
				})
				.addOnFailureListener(error -> emitSignal(CHECK_FAILED.getName(), String.valueOf(error.getMessage())));
	}

	/** Starts Play's update screen. Emits flow_result with Activity.RESULT_OK / RESULT_CANCELED. */
	@UsedByGodot
	public boolean startUpdate(boolean immediate) {
		Activity activity = getActivity();
		int type = immediate ? AppUpdateType.IMMEDIATE : AppUpdateType.FLEXIBLE;
		if (activity == null || lastInfo == null || !lastInfo.isUpdateTypeAllowed(type)) {
			return false;
		}
		if (!immediate) {
			startListening();
		}
		manager().startUpdateFlow(lastInfo, activity, AppUpdateOptions.newBuilder(type).build())
				.addOnSuccessListener(result -> emitSignal(FLOW_RESULT.getName(), result))
				.addOnFailureListener(error -> emitSignal(FLOW_RESULT.getName(), Activity.RESULT_CANCELED));
		// The info is used up by the flow; the next check fetches a fresh one.
		lastInfo = null;
		return true;
	}

	/** Installs a downloaded flexible update; Play restarts the game. */
	@UsedByGodot
	public void completeUpdate() {
		manager().completeUpdate();
	}

	@Override
	public void onMainResume() {
		// An immediate update interrupted by leaving the app must be resumed (Play's rule).
		if (manager == null) {
			return;
		}
		manager.getAppUpdateInfo().addOnSuccessListener(info -> {
			Activity activity = getActivity();
			if (activity != null && info.updateAvailability()
					== UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
				manager.startUpdateFlow(info, activity, AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build());
			} else if (info.installStatus() == InstallStatus.DOWNLOADED) {
				emitSignal(INSTALL_STATUS.getName(), InstallStatus.DOWNLOADED,
						info.bytesDownloaded(), info.totalBytesToDownload());
			}
		});
	}

	@Override
	public void onMainDestroy() {
		stopListening();
	}

	private void startListening() {
		if (!listening) {
			manager().registerListener(listener);
			listening = true;
		}
	}

	private void stopListening() {
		if (listening && manager != null) {
			manager.unregisterListener(listener);
			listening = false;
		}
	}
}
