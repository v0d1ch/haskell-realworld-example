{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE DuplicateRecordFields #-}
module Conduit.Db.Schema.User where

import RIO hiding (set)
import Rel8
import Hasql.Connection ( Connection )

import Conduit.Core.User
import Conduit.Core.Password

data UserEntity f = UserEntity
    { entityUserId       :: Column f UserId
    , entityUserName     :: Column f Username
    , entityUserEmail    :: Column f EmailAddress
    , entityUserPassword :: Column f HashedPassword
    , entityUserSalt     :: Column f Salt
    , entityUserBio      :: Column f Text
    , entityUserImage    :: Column f Text
    }
    deriving stock (Generic)
    deriving anyclass (Rel8able)

deriving stock instance f ~ Result => Show (UserEntity f)

userSchema :: TableSchema (UserEntity Name)
userSchema = TableSchema
    { name = "users"
    , schema = Nothing
    , columns = UserEntity
        { entityUserId       = "user_id"
        , entityUserName     = "user_username"
        , entityUserEmail    = "user_email"
        , entityUserPassword = "user_password"
        , entityUserSalt     = "user_salt"
        , entityUserBio      = "user_bio"
        , entityUserImage    = "user_image"
        }
    }

mapUserEntityToUser :: UserEntity Result -> User
mapUserEntityToUser entity = User
    { userId     = entityUserId entity
    , userName   = entityUserName entity
    , userEmail  = entityUserEmail entity
    , userBio    = entityUserBio entity
    , userImage  = entityUserImage entity
    }

updateUserProperties :: User -> UserEntity Expr -> UserEntity Expr
updateUserProperties user expr = expr
                                { entityUserName = lit (userName user)
                                , entityUserEmail = lit (userEmail user)
                                , entityUserBio = lit (userBio user)
                                , entityUserImage = lit (userImage user)
                                }

updatePasswordAndSalt :: (HashedPassword, Salt) -> UserEntity Expr ->  UserEntity Expr
updatePasswordAndSalt (hash, salt) expr = expr
                                { entityUserSalt = lit salt
                                , entityUserPassword = lit hash
                                }

getUserByIdStmt :: Expr UserId -> Query (UserEntity Expr)
getUserByIdStmt uid = do
    a <- each userSchema
    where_ $ entityUserId a ==. uid
    return a

getUserByNameStmt :: Username -> Query (UserEntity Expr)
getUserByNameStmt name = do
    a <- each userSchema
    where_ $ entityUserName a ==. lit name
    return a

getUserByEmailStmt :: EmailAddress  -> Query (UserEntity Expr)
getUserByEmailStmt email = do
    a <- each userSchema
    where_ $ entityUserEmail a ==. lit email
    return a

insertUserStmt :: User -> (HashedPassword, Salt) -> Insert [UserId]
insertUserStmt user (hash, salt) = Insert
    { into = userSchema
    , rows = values [ UserEntity
                        { entityUserId       = unsafeCastExpr $ nextval "users_user_id_seq"
                        , entityUserName     = lit (userName user)
                        , entityUserEmail    = lit (userEmail user)
                        , entityUserBio      = lit (userBio user)
                        , entityUserImage    = lit (userImage user)
                        , entityUserPassword = lit hash
                        , entityUserSalt     = lit salt
                        }
                    ]
    , onConflict = DoNothing
    , returning = Projection entityUserId
    }

updateUserStmt :: User -> Maybe (HashedPassword, Salt) -> Update Int64
updateUserStmt user mbPassword =
    Update
        { target = userSchema
        , from = pure ()
        , updateWhere = \_ o -> entityUserId o ==. lit (userId user)
        , set = setter
        , returning = NumberOfRowsAffected
        }
    where
        setter _ = case mbPassword of
            Just password -> updatePasswordAndSalt password . updateUserProperties user
            _             -> updateUserProperties user
