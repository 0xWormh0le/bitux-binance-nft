const ServiceFee = artifacts.require("ServiceFee");

module.exports = async function (deployer) {
    await deployer.deploy(
        ServiceFee,
        250,
        250,
    );

    serviceFeeInstance = await ServiceFee.deployed();
};
