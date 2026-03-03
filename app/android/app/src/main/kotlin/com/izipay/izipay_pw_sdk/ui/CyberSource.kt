package com.izipay.izipay_pw_sdk.ui

import android.content.Context
import android.util.Log
import com.lexisnexisrisk.threatmetrix.rl.TMXConfig
import com.lexisnexisrisk.threatmetrix.rl.TMXEndNotifier
import com.lexisnexisrisk.threatmetrix.rl.TMXProfiling
import com.lexisnexisrisk.threatmetrix.rl.TMXProfilingConnectionsInterface
import com.lexisnexisrisk.threatmetrix.rl.TMXProfilingHandle
import com.lexisnexisrisk.threatmetrix.rl.TMXProfilingOptions
import com.lexisnexisrisk.threatmetrix.rl.tmxprofilingconnections.TMXProfilingConnections
import java.util.concurrent.TimeUnit

fun initCyberSource(context: Context, guid: String, url: String, userOrg: String, userScoring: String) {
    val profilingConnections: TMXProfilingConnectionsInterface = TMXProfilingConnections()
        .setConnectionTimeout(20, TimeUnit.SECONDS)
        .setRetryTimes(3)

    val config: TMXConfig = TMXConfig()
        .setOrgId(userOrg)
        .setFPServer(url)
        .setContext(context)

    config.setProfilingConnections(profilingConnections)
    TMXProfiling.getInstance().init(config)

    val options = TMXProfilingOptions().setCustomAttributes(null)
    options.setSessionID("$userScoring $guid")
    val profilingHandle = TMXProfiling.getInstance().profile(
        options,
        CompletionNotifier()
    )
}
class CompletionNotifier : TMXEndNotifier {
    override fun complete(result: TMXProfilingHandle.Result?) {
        Log.i("PROFILE COMPLETED", "Profile completed with: " + result!!.sessionID + " -" + result.status.desc)
    }
}