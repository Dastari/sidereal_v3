use thiserror::Error;

#[derive(Debug, Error)]
pub enum PersistenceError {
    #[error("not implemented")]
    NotImplemented,
}

pub type Result<T> = std::result::Result<T, PersistenceError>;
