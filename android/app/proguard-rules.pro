# WorkManager (used by the Glance widget) creates its Room database by reflection, from the
# generated WorkDatabase_Impl; without this R8 removes that constructor and the app crashes at
# launch.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
