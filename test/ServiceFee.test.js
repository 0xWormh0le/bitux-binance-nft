const ServiceFeeProxy = artifacts.require("ServiceFeeProxy");
const ServiceFee = artifacts.require("ServiceFee");

contract("ServiceFee", (accounts) => {
    var servicefee_contract;
    var servicefeeproxy_contract;

    before(async () => {
        await ServiceFee.new(250, 250, { from: accounts[1] }).then(function (instance) {
            servicefee_contract = instance;
        });

        await ServiceFeeProxy.new({ from: accounts[1] }).then(function (instance) {
            servicefeeproxy_contract = instance;
        });

        await servicefee_contract.addProxy(servicefeeproxy_contract.address, { from: accounts[1] })
        await servicefeeproxy_contract.setServiceFeeContract(servicefee_contract.address, { from: accounts[1] })
        await servicefeeproxy_contract.setServiceFeeRecipient(accounts[5], { from: accounts[1] });
    });

    describe("servie fee", () => {
        it("can not access service fee contract from anywhere", async () => {
            let thrownError;
            try {
                await servicefee_contract.getSellServiceFeeBps(accounts[0], { from: accounts[3] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'Ownable: caller is not the proxy',
            )
        });
        it("can access service fee contract from only proxy", async () => {
            await servicefeeproxy_contract.getSellServiceFeeBps(accounts[0], { from: accounts[3] });
        });
        it("can not add or remove proxy address in service fee contract from anywhere", async () => {
            let thrownError;
            try {
                await servicefee_contract.addProxy(accounts[0], { from: accounts[3] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'Ownable: caller is not the admin',
            )

            try {
                await servicefee_contract.removeProxy(servicefee_contract.address, { from: accounts[3] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'Ownable: caller is not the admin',
            )
        });
        it("only admin can add or remove the proxy address in service fee contract", async () => {
            await servicefee_contract.addProxy(servicefeeproxy_contract.address, { from: accounts[1] });
            await servicefee_contract.removeProxy(servicefeeproxy_contract.address, { from: accounts[1] });
        });
        it("can not add external address as proxy", async () => {
            let thrownError;
            try {
                await servicefee_contract.addProxy(accounts[0], { from: accounts[1] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'ServiceFee.addProxy: address is not a contract address',
            )
        });
        it("can not change service fee recipient address from anywhere", async () => {
            let thrownError;
            try {
                await servicefeeproxy_contract.setServiceFeeRecipient(accounts[0], { from: accounts[2] });
            } catch (error) {
                thrownError = error;
            }

            assert.include(
                thrownError.message,
                'Ownable: caller is not the admin',
            )
        });
        it("only admin can change the recipient address using proxy", async () => {
            await servicefee_contract.addProxy(servicefeeproxy_contract.address, { from: accounts[1] });
            await servicefeeproxy_contract.setServiceFeeRecipient(accounts[0], { from: accounts[1] });
            const serviceFeeRecipient = await servicefeeproxy_contract.getServiceFeeRecipient({ from: accounts[1] });
            assert.equal(serviceFeeRecipient, accounts[0]);
        });
    });
});
