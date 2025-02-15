pub const file_body = "contract SecondSwap_StepVesting is SecondSwap_Vesting {
    using SafeERC20 for IERC20;

    // ... Code omitted for brevity

    struct Vesting {
        uint256 stepsClaimed;
        uint256 amountClaimed;
        uint256 totalAmount;
    }

    // ... Code omitted for brevity

    function claimable(address _beneficiary) public view returns (uint256, uint256) {
        if (block.timestamp < startTime) {
            return (0, 0);
        }

        Vesting memory vesting = _vestings[_beneficiary];

        if (vesting.totalAmount == 0) {
            return (0, 0);
        }

        uint256 elapsedTime = block.timestamp - startTime;
        uint256 currentStep = Math.min(elapsedTime / stepDuration, numOfSteps);

        uint256 claimableSteps = currentStep - vesting.stepsClaimed;

        uint256 claimableAmount = 
            ((vesting.totalAmount - vesting.amountClaimed) * (currentStep - vesting.stepsClaimed)) 
            / (numOfSteps - vesting.stepsClaimed);

        return (claimableAmount, claimableSteps);
    }

    // ... Code omitted for brevity

    function _createVesting(
        address _beneficiary,
        uint256 _totalAmount,
        uint256 _stepsClaimed,
        bool _isInternal
    ) internal {
        // This function has been trimmed down for brevity

        if (_vestings[_beneficiary].totalAmount == 0) {
            _vestings[_beneficiary] = Vesting({
                stepsClaimed: _stepsClaimed,
                amountClaimed: 0,
                totalAmount: _totalAmount
            });
        } else {
            _vestings[_beneficiary].totalAmount += _totalAmount;
        }
    }
}"
