package com.example.myapplication

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [User::class], version = 1, exportSchema = false)
abstract class PaperlessDatabase : RoomDatabase() {

    abstract fun userDao(): UserDao

    companion object {
        @Volatile
        private var INSTANCE: PaperlessDatabase? = null

        fun getDatabase(context: Context): PaperlessDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    PaperlessDatabase::class.java,
                    "paperless_database"
                ).build()
                INSTANCE = instance
                instance
            }
        }
    }
}