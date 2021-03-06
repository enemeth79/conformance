{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
module Web.ConsumerData.Au.Api.Types.ResponseTest where

import Control.Lens

import Data.Profunctor  (lmap)
import Servant.Links    (Link)
import Test.Tasty       (TestTree)
import Test.Tasty.HUnit (testCase, (@?=))
import Text.URI         (Authority (..), RText, RTextLabel (PathPiece))
import Text.URI.QQ      (host, pathPiece, scheme, uri)

import Web.ConsumerData.Au.Api.Types

dummyLinkQualifier :: [RText 'PathPiece] -> LinkQualifier
dummyLinkQualifier pps = LinkQualifier
  [scheme|http|]
  (Authority
    { authUserInfo = Nothing
    , authHost     = [host|localhost|]
    , authPort     = Just $ 1337
    })
  pps

test_linkToUri :: [TestTree]
test_linkToUri =
  [ testCase "without prefix" $
    linkToUri (dummyLinkQualifier []) complexLink @?=
    [uri|http://localhost:1337/banking/accounts/1337/13|]
  , testCase "with prefix" $
    linkToUri (dummyLinkQualifier [[pathPiece|api|]]) complexLink @?=
    [uri|http://localhost:1337/api/banking/accounts/1337/13|]
  ]

test_mkPaginatedResponse :: [TestTree]
test_mkPaginatedResponse =
  [ testCase "single page" $
    (mkPaginatedResponse
     True
     (dummyLinkQualifier [])
     (Paginator (PageNumber 1) (PageNumber 1) 10 (lmap Just accountsLink))
    )
    @?=
    (Response
     True
     (LinksPaginated
      [uri|http://localhost:1337/banking/accounts?page=1|]
      Nothing
      Nothing
      Nothing
      Nothing
     )
     (MetaPaginated 10 1)
    )
  , testCase "many pages first" $
    (mkPaginatedResponse
     True
     (dummyLinkQualifier [])
     (Paginator (PageNumber 1) (PageNumber 5) 120 (lmap Just accountsLink))
    )
    @?=
    (Response
     True
     (LinksPaginated
      [uri|http://localhost:1337/banking/accounts?page=1|]
      Nothing
      Nothing
      (Just [uri|http://localhost:1337/banking/accounts?page=2|])
      (Just [uri|http://localhost:1337/banking/accounts?page=5|])
     )
     (MetaPaginated 120 5)
    )
  , testCase "many pages middle" $
    (mkPaginatedResponse
     True
     (dummyLinkQualifier [])
     (Paginator (PageNumber 3) (PageNumber 5) 120 (lmap Just accountsLink))
    )
    @?=
    (Response
     True
     (LinksPaginated
      [uri|http://localhost:1337/banking/accounts?page=3|]
      (Just [uri|http://localhost:1337/banking/accounts?page=1|])
      (Just [uri|http://localhost:1337/banking/accounts?page=2|])
      (Just [uri|http://localhost:1337/banking/accounts?page=4|])
      (Just [uri|http://localhost:1337/banking/accounts?page=5|])
     )
     (MetaPaginated 120 5)
    )
  , testCase "many pages last" $
    (mkPaginatedResponse
     True
     (dummyLinkQualifier [])
     (Paginator (PageNumber 5) (PageNumber 5) 120 (lmap Just accountsLink))
    )
    @?=
    (Response
     True
     (LinksPaginated
      [uri|http://localhost:1337/banking/accounts?page=5|]
      (Just [uri|http://localhost:1337/banking/accounts?page=1|])
      (Just [uri|http://localhost:1337/banking/accounts?page=4|])
      Nothing
      Nothing
     )
     (MetaPaginated 120 5)
    )
  ]

accountsLink :: Maybe PageNumber -> Link
accountsLink pn = links ^.bankingLinks.bankingAccountsLinks.accountsGet.to ($ pn)

complexLink :: Link
complexLink = links
  ^.bankingLinks.bankingAccountsLinks.accountsByIdLinks
  .to ($ AccountId (AsciiString "1337")).accountTransactionByIdGet.to ($ TransactionId (AsciiString "13"))
