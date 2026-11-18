# The SDK reads Firebase Analytics' app instance ID by reflection when the app includes it.
-keep class com.google.firebase.analytics.FirebaseAnalytics {
    public static com.google.firebase.analytics.FirebaseAnalytics getInstance(android.content.Context);
    public com.google.android.gms.tasks.Task getAppInstanceId();
}
-keep class com.google.android.gms.tasks.Tasks {
    public static java.lang.Object await(com.google.android.gms.tasks.Task, long, java.util.concurrent.TimeUnit);
}
-keep class com.google.android.gms.tasks.Task
