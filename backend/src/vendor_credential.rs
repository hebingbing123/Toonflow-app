//! Vendor credential encryption utilities.
//!
//! NOTE: This is a framework implementation using AES-256-GCM with a key derived from
//! environment variable. Production should integrate with a proper KMS (AWS KMS, HashiCorp Vault, etc.)

#![allow(dead_code)]

use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use sha2::{Digest, Sha256};

const KEY_ENV_VAR: &str = "TOONFLOW_VENDOR_CREDENTIAL_KEY";

/// Get encryption key from environment (32 bytes for AES-256)
fn get_encryption_key() -> Option<[u8; 32]> {
    std::env::var(KEY_ENV_VAR).ok().map(|key| {
        let mut hasher = Sha256::new();
        hasher.update(key.as_bytes());
        let result = hasher.finalize();
        let mut key_bytes = [0u8; 32];
        key_bytes.copy_from_slice(&result);
        key_bytes
    })
}

/// Encrypt plaintext using AES-256-GCM
/// Returns: nonce (12 bytes) + ciphertext + tag (16 bytes)
pub fn encrypt(plaintext: &str) -> Option<Vec<u8>> {
    let key = get_encryption_key()?;
    let cipher = Aes256Gcm::new_from_slice(&key).ok()?;

    // Generate random nonce
    let nonce_bytes: [u8; 12] = rand::random();
    let nonce = Nonce::from_slice(&nonce_bytes);

    // Encrypt
    let ciphertext = cipher.encrypt(nonce, plaintext.as_bytes()).ok()?;

    // Prepend nonce to ciphertext for storage
    let mut result = nonce_bytes.to_vec();
    result.extend_from_slice(&ciphertext);
    Some(result)
}

/// Decrypt ciphertext using AES-256-GCM
/// Expects: nonce (12 bytes) + ciphertext + tag (16 bytes)
pub fn decrypt(ciphertext: &[u8]) -> Option<String> {
    if ciphertext.len() < 28 {
        // 12 nonce + 16 tag minimum
        return None;
    }

    let key = get_encryption_key()?;
    let cipher = Aes256Gcm::new_from_slice(&key).ok()?;

    // Extract nonce
    let nonce = Nonce::from_slice(&ciphertext[..12]);
    let encrypted_data = &ciphertext[12..];

    // Decrypt
    let plaintext = cipher.decrypt(nonce, encrypted_data).ok()?;
    String::from_utf8(plaintext).ok()
}

/// Get a hint for the key (last 4 characters)
pub fn key_hint(key: &str) -> String {
    if key.len() <= 4 {
        key.to_string()
    } else {
        format!("...{}", &key[key.len() - 4..])
    }
}

/// Check if encryption is configured
pub fn is_encryption_configured() -> bool {
    get_encryption_key().is_some()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_key_hint() {
        assert_eq!(key_hint("sk-1234"), "...1234");
        assert_eq!(key_hint("1234"), "1234");
        assert_eq!(key_hint("12"), "12");
    }

    #[test]
    fn test_encrypt_decrypt() {
        // This test requires TOONFLOW_VENDOR_CREDENTIAL_KEY to be set
        if std::env::var(KEY_ENV_VAR).is_err() {
            return; // Skip test if key not configured
        }

        let plaintext = "sk-test-key-12345";
        let encrypted = encrypt(plaintext).expect("encryption failed");
        let decrypted = decrypt(&encrypted).expect("decryption failed");
        assert_eq!(decrypted, plaintext);
    }
}
