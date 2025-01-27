{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DeriveGeneric #-}
module Conduit.Api.User where

import RIO
import Data.Aeson
import Servant

import Conduit.Api.Common
import Conduit.App
import Conduit.Core.User
import Conduit.Core.Password
import qualified Conduit.Repository.User as UserRepository
import Conduit.Util

data UserResponse = UserResponse
    { urUsername :: Text
    , urEmail    :: Text
    , urBio      :: Text
    , urImage    :: Text
    } deriving (Show, Generic)

instance ToJSON UserResponse where
    toJSON = genericToJSON $ toJsonOptions 2

data UpdateUserRequest = UpdateUserRequest
    { uurUsername :: Maybe Text
    , uurEmail    :: Maybe Text
    , uurPassword :: Maybe Text
    , uurBio      :: Maybe Text
    , uurImage    :: Maybe Text
    } deriving (Show, Generic)

instance FromJSON UpdateUserRequest where
    parseJSON = genericParseJSON $ toJsonOptions 3

mapUserToUserResponse :: User -> UserResponse
mapUserToUserResponse user = UserResponse
    { urUsername = getUsername $ userName user
    , urEmail    = getEmailAddress $ userEmail user
    , urBio      = userBio user
    , urImage    = userImage user
    }

type UserApi = AuthProtect "Required"
                    :> "user"
                    :> Get '[JSON] (UserData UserResponse)
          :<|> AuthProtect "Required"
                    :> "user"
                    :> ReqBody '[JSON] (UserData UpdateUserRequest)
                    :> Put '[JSON] (UserData UserResponse)

getUserHandler :: User -> AppM (UserData UserResponse)
getUserHandler = return . UserData . mapUserToUserResponse

updateUserHandler :: User -> UserData UpdateUserRequest -> AppM (UserData UserResponse)
updateUserHandler user (UserData user') = do
    succeed <- UserRepository.updateUser updatedUser newPassword
    if succeed then
        return $ UserData $ mapUserToUserResponse user
    else
        throwIO err400
    where
        newName = maybe (userName user) Username (uurUsername user')
        newEmail = maybe (userEmail user) EmailAddress (uurUsername user')
        newPassword = Password <$> uurPassword user'
        newBio = fromMaybe (userBio user) (uurBio user')
        newImage = fromMaybe (userImage user) (uurImage user')
        updatedUser = user
            { userName = newName
            , userEmail = newEmail
            , userBio = newBio
            , userImage = newImage
            }

userServer :: ServerT UserApi AppM
userServer = getUserHandler :<|> updateUserHandler
