package com.example.myapplication

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.enableEdgeToEdge
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import androidx.lifecycle.lifecycleScope
import com.example.myapplication.databinding.ActivityProfileBinding
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.firstOrNull

class ProfileActivity : AppCompatActivity() {

    private lateinit var binding: ActivityProfileBinding
    private lateinit var db: PaperlessDatabase

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        binding = ActivityProfileBinding.inflate(layoutInflater)
        setContentView(binding.root)

        ViewCompat.setOnApplyWindowInsetsListener(binding.main) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        setSupportActionBar(binding.toolbar)
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        db = PaperlessDatabase.getDatabase(this)

        loadUserData()

        binding.saveButton.setOnClickListener {
            saveUserData()
        }
    }

    private fun loadUserData() {
        lifecycleScope.launch {
            val user = db.userDao().getUser().firstOrNull()
            user?.let {
                binding.nameEdit.setText(it.name)
                binding.emailEdit.setText(it.email)
                binding.paymentEdit.setText(it.paymentMethod)
            }
        }
    }

    private fun saveUserData() {
        val user = User(
            name = binding.nameEdit.text.toString(),
            email = binding.emailEdit.text.toString(),
            paymentMethod = binding.paymentEdit.text.toString()
        )
        lifecycleScope.launch {
            db.userDao().insertOrUpdate(user)
            Toast.makeText(this@ProfileActivity, "Profile saved to Room DB", Toast.LENGTH_SHORT).show()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }
}