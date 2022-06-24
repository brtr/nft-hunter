require("@rails/ujs").start();
require("turbolinks").start();
require("jquery");
require("chartkick");
require("chart.js");
require("moment");
require("ethers");
require("../stylesheets/application.scss");

import 'bootstrap/dist/css/bootstrap';
import 'bootstrap/dist/js/bootstrap';
import Chart from 'chart.js/auto';
import 'chartjs-adapter-moment';
import { ethers } from 'ethers';

global.Chart = Chart;

let loginAddress = localStorage.getItem("loginAddress");
const hunterPassAddress = NODE_ENV["HUNTER_PASS_ADDRESS"];
const hunterPassAbi = NODE_ENV["HUNTER_PASS_ABI"];

const provider = new ethers.providers.Web3Provider(web3.currentProvider);
const signer = provider.getSigner();
const hunterPassContract = new ethers.Contract(hunterPassAddress, hunterPassAbi, provider);
const TargetChain = {id: NODE_ENV["CHAIN_ID"], name: NODE_ENV["CHAIN_NAME"]};

async function checkChainId () {
    const { chainId } = await provider.getNetwork();
    if (chainId != parseInt(TargetChain.id)) {
        alert("We don't support this chain, please switch to " + TargetChain.name + " and refresh");
        return;
    }
}

function replaceChar(origString, firstIdx, lastIdx, replaceChar) {
    let firstPart = origString.substr(0, firstIdx);
    let lastPart = origString.substr(lastIdx);

    let newString = firstPart + replaceChar + lastPart;
    return newString;
}

const checkMetamaskLogin = async function() {
  $("#spinner").removeClass("hide");
  const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
  changeAddress(accounts);
  $("#spinner").addClass("hide");
}

function changeAddress(accounts) {
  if (accounts.length > 0) {
      localStorage.setItem("loginAddress", accounts[0]);
      loginAddress = accounts[0];
      login();
  } else {
      localStorage.removeItem("loginAddress");
      loginAddress = null;
      toggleAddress();
  }
}

const toggleAddress = function() {
    if(loginAddress) {
        $("#login_address").text(replaceChar(loginAddress, 6, -4, "..."));
        $(".loginBtns .navbar-tool").removeClass("hide");
        $(".loginBtns .connect-btn").addClass("hide");
        $(".actions").removeClass("hide");
    } else {
        $(".actions").addClass("hide");
        $(".loginBtns .navbar-tool").addClass("hide");
        $(".loginBtns .connect-btn").removeClass("hide");
    }
}

const login = function() {
    $.ajax({
        url: "/login",
        method: "post",
        data: { address: loginAddress }
    }).done(function(data) {
        if (data.success) {
            location.reload();
        }
    })
}

const checkNft = async function() {
    let error_code;
    const url = "/not_permitted?error_code="
    if ($("#extensions").length > 0 || $("#myNfts").length > 0 || $(".qanda").length > 0 || $(".mint").length > 0) {
        $(".content").fadeIn(1000);
    } else {
        if (loginAddress) {
            const balance = await hunterPassContract.balanceOf(loginAddress);
            console.log("nft balance", balance);
            if (balance < 1) { error_code = 1}
        } else {
            error_code = 2;
        }

        if (error_code) {
            $.get(url + error_code, function(data) {
                $(".content").html('<h3 class="text-center">' + data.message + '</h3>').fadeIn();
            });
        }
    }
    const minted = await hunterPassContract.totalSupply();
    $("#mintedQty").text(minted);
}

$(document).on('turbolinks:load', function() {
    'use strict';

    $(function() {
        $("#spinner").fadeOut("3000", function() {
            checkNft();
        });

        $('[data-bs-toggle="tooltip"]').tooltip({html: true});

        $(".period_targets input").on("click", function() {
            this.form.submit();
        })

        toggleAddress();
        checkChainId();

        $("#loginBtn").on("click", function(e){
            e.preventDefault();
            checkMetamaskLogin();
        });

        $("#logoutBtn").on("click", function(e){
            $("#spinner").removeClass("hide");
            e.preventDefault();
            localStorage.removeItem("loginAddress");
    
            $.ajax({
                url: "/logout",
                method: "post"
            }).done(function(data) {
                if (data.success) {
                    location.reload();
                }
            })
        });

        $(".synBtn").on("click", function(){
            $("#spinner").removeClass("hide");
        })

        $(".sidebar-toggle").on("click", function(){
            $("#sidebar").toggleClass("collapsed");
        })

        $(".js-settings-toggle").on("click", function() {
            $(".js-settings").toggleClass("open");
        })

        $(".mintBtn").on("click", function() {
            // $("#spinner").fadeIn();
            // if (loginAddress) {
            //     hunterPassContract.connect(signer).mint()
            //     .then(async (tx) => {
            //         console.log("tx: ", tx)
            //         await tx.wait();
            //         alert("Mint successfully!");
            //         location.reload();
            //     }).catch(err => {
            //         console.log("error", err);
            //         location.reload();
            //     })
            // } else {
            //     checkMetamaskLogin();
            // }
        })
    })

    // detect Metamask account change
    ethereum.on('accountsChanged', function (accounts) {
        console.log('accountsChanges',accounts);
        if (accounts.length > 0) {
            localStorage.setItem("loginAddress", accounts[0]);
            loginAddress = accounts[0];
            login();
        } else {
            localStorage.removeItem("loginAddress");
            loginAddress = null;
        }
        location.reload();
    });

    // detect Network account change
    ethereum.on('chainChanged', function(networkId){
        console.log('networkChanged',networkId);
        if (networkId != parseInt(TargetChain.id)) {
            alert("We don't support this chain, please switch to " + TargetChain.name + " and refresh");
        } else {
            location.reload();
        }
    })
})
