pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract BetMe {
	using SafeMath for uint256;

	string public Assertion;
	uint256 public Deadline;
	uint256 public ArbiterFee;
	uint256 public ArbiterPenaltyAmount;

	uint256 public StateVersion;
	uint256 private betAmount;

	address public OwnerAddress;
	address public ArbiterAddress;
	address public OpponentAddress;

	bool public IsArbiterAddressConfirmed;
	bool public IsOpponentBetConfirmed;
	bool public ArbiterHasVoted;
	bool public IsDecisionMade;
	bool public IsAssertionTrue;
	bool public IsOwnerTransferMade;
	bool public IsArbiterTransferMade;

	constructor(
		string  _assertion,
		uint256 _deadline,
		uint256 _fee,
		address _arbiterAddr,
		address _opponentAddr
	) public {
		OwnerAddress = msg.sender;
		_setAssertionText(_assertion);
		_setDeadline(_deadline);
		_setArbiterFee(_fee);
		ArbiterAddress  = _arbiterAddr;
		OpponentAddress = _opponentAddr;
	}

	modifier onlyOwner() {
		require(msg.sender == OwnerAddress);
		_;
	}

	modifier forbidOwner() {
		require(msg.sender != OwnerAddress);
		_;
	}

	modifier onlyValidArbiterandNotVoted() {
		require(msg.sender == ArbiterAddress);
		require(IsArbiterAddressConfirmed);
		require(!ArbiterHasVoted);
		_;
	}

	modifier forbidArbiter() {
		require(msg.sender != ArbiterAddress);
		_;
	}

	modifier onlyArbiterCandidate() {
		require(!IsArbiterAddressConfirmed);
		require(msg.sender == ArbiterAddress);
		_;
	}

	modifier increaseState() {
		StateVersion = StateVersion.add(1);
		_;
	}

	modifier whileBetNotMade() {
		require(betAmount == 0);
		_;
	}

	modifier requireOwnerBetIsMade() {
		require(betAmount != 0);
		_;
	}

	modifier requireArbiterNotConfirmed() {
		require(!IsArbiterAddressConfirmed);
		_;
	}

	modifier stateNumberMatches(uint256 _agreedState) {
		require(StateVersion == _agreedState);
		_;
	}

	modifier requireArbiterConfirmed() {
		require(IsArbiterAddressConfirmed);
		_;
	}

	modifier requireOpponentBetIsMade() {
		require(IsOpponentBetConfirmed);
		_;
	}

	modifier requireOpponentBetIsNotMade() {
		require(!IsOpponentBetConfirmed);
		_;
	}

	function getTime() public view returns (uint256) {
		return now;
	}

	function setAssertionText(string _text) public onlyOwner increaseState whileBetNotMade {
		_setAssertionText(_text);
	}

	function _setAssertionText(string _text) internal {
		require(bytes(_text).length > 0);
		Assertion = _text;
	}

	function setDeadline(uint256 _timestamp) public onlyOwner increaseState requireArbiterNotConfirmed {
		_setDeadline(_timestamp);
	}

	function _setDeadline(uint256 _timestamp) internal {
		require(_timestamp > getTime());
		Deadline = _timestamp;
	}

	function setArbiterFee(uint256 _percent) public onlyOwner requireArbiterNotConfirmed increaseState {
		_setArbiterFee(_percent);
	}

	function _setArbiterFee(uint256 _percent) internal {
		require(_percent < 100e18); // 100.0% float as integer with decimal=18
		ArbiterFee      = _percent;
	}

	function setOpponentAddress(address _addr) public 
		onlyOwner 
		increaseState
		requireOpponentBetIsNotMade
	{
		require(_addr != address(OpponentAddress));
		OpponentAddress = _addr;
	}

	function setArbiterAddress(address _addr) public onlyOwner requireArbiterNotConfirmed increaseState {
		require(_addr != address(ArbiterAddress));
		require(_addr != address(OwnerAddress));
		ArbiterAddress = _addr;
	}

	function bet() public payable onlyOwner whileBetNotMade {
		betAmount = msg.value;
	}

	function currentBet() public view returns (uint256){
		return betAmount;
	}

	function setArbiterPenaltyAmount(uint256 _amount) public onlyOwner requireArbiterNotConfirmed increaseState {
		require(_amount != ArbiterPenaltyAmount);
		ArbiterPenaltyAmount = _amount;
	}

	function agreeToBecameArbiter(uint256 _agreedState) public payable 
		onlyArbiterCandidate
		requireOwnerBetIsMade 
		stateNumberMatches(_agreedState)
	{
		require(ArbiterAddress != address(0));
		IsArbiterAddressConfirmed = true;
	}

	function arbiterSelfRetreat() public requireArbiterConfirmed requireOpponentBetIsNotMade {
		require(msg.sender == ArbiterAddress);
		uint256 _value = ArbiterPenaltyAmount;
		IsArbiterAddressConfirmed = false;
		ArbiterPenaltyAmount = 0;
		if (_value > 0 ) {
			ArbiterAddress.transfer(_value);
		}
	}

	function betAssertIsFalse(uint256 _agreedState) public payable 
		requireOwnerBetIsMade 
		forbidOwner
		requireArbiterConfirmed
		forbidArbiter
		stateNumberMatches(_agreedState) 
		requireOpponentBetIsNotMade
	{
		require(msg.value == betAmount);
		if (OpponentAddress == address(0)) {
			OpponentAddress = msg.sender;
		} else {
			require(OpponentAddress == msg.sender);
		}
		IsOpponentBetConfirmed = true;
	}

	function agreeAssertionTrue() public onlyValidArbiterandNotVoted requireOpponentBetIsMade {
		ArbiterHasVoted = true;
		IsDecisionMade = true;
		IsAssertionTrue = true;
	}

	function agreeAssertionFalse() public onlyValidArbiterandNotVoted requireOpponentBetIsMade {
		ArbiterHasVoted = true;
		IsDecisionMade = true;
	}

	function agreeAssertionUnresolvable() public onlyValidArbiterandNotVoted requireOpponentBetIsMade {
		ArbiterHasVoted = true;
	}

	function withdraw() public {
		if (msg.sender == ArbiterAddress) {
			require(!IsArbiterTransferMade);
			IsArbiterTransferMade = true;
			ArbiterAddress.transfer(ArbiterPenaltyAmount);
		} else if (msg.sender == OwnerAddress) {
			require(IsAssertionTrue);
			require(!IsOwnerTransferMade);
			IsOwnerTransferMade = true;
			OwnerAddress.transfer(betAmount.mul(2));
		} else {
			revert();
		}
	}

	function ArbiterFeeAmountInEther() public view returns (uint256){
		return betAmount.mul(ArbiterFee).div(1e20);
	}

	function ownerPayout() public view returns (uint256) {
		if (ArbiterHasVoted && IsDecisionMade) {
			return (IsAssertionTrue ? betAmount.mul(2).sub(ArbiterFeeAmountInEther()) : 0);
		} else {
			return betAmount;
		}
	}

	function arbiterPayout() public view returns (uint256 amount) {
		if ( getTime() > Deadline && !ArbiterHasVoted) {
			return 0;
		}
		if (!ArbiterHasVoted || IsDecisionMade) {
			amount = ArbiterFeeAmountInEther();
		}
		if (IsArbiterAddressConfirmed) {
			amount = amount.add(ArbiterPenaltyAmount);
		}
	}
}
