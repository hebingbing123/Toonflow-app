use jsonwebtoken::{decode, Algorithm, DecodingKey, Validation};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Claims {
    pub sub: String,
    // Present for JWT deserialization; validated by `jsonwebtoken::Validation`.
    #[allow(dead_code)]
    exp: i64,
    pub email: Option<String>,
}

pub fn verify_supabase_user_jwt(
    token: &str,
    secret: &[u8],
) -> Result<Claims, jsonwebtoken::errors::Error> {
    let mut validation = Validation::new(Algorithm::HS256);
    validation.validate_exp = true;
    validation.set_audience(&["authenticated"]);

    let key = DecodingKey::from_secret(secret);
    let data = decode::<Claims>(token, &key, &validation)?;
    Ok(data.claims)
}
