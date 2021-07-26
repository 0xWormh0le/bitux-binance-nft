const ServiceFeeProxy = artifacts.require("ServiceFeeProxy");
const ServiceFee = artifacts.require("ServiceFee");

module.exports = async function (deployer) {
    await deployer.deploy(
        ServiceFeeProxy
    );

    serviceFeeProxyInstance = await ServiceFeeProxy.deployed();
};
