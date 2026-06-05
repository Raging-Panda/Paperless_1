package com.example.myapplication

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "users")
data class User(
    @PrimaryKey val id: Int = 1, // single user profile
    val name: String = "",
    val email: String = "",
    val paymentMethod: String = ""
)