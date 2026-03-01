// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title  PongRewards
 * @notice Holds ETH funded by the contract owner and distributes micro-rewards
 *         to players who connect their MetaMask wallet while playing the
 *         web-based Pong game.
 *
 * Reward structure (configurable by owner):
 *   • perRally  – awarded each time the ball hits a paddle
 *   • perPoint  – awarded to the scoring player each point
 *   • winBonus  – bonus awarded to the match winner
 *
 * The owner calls recordGame() on behalf of players (or a trusted relayer does).
 * Players call claimRewards() themselves to pull their accumulated ETH.
 *
 * Anti-abuse:
 *   • Minimum time between claims per address (cooldown)
 *   • Per-session reward cap
 *   • Owner can pause reward accrual
 */
contract PongRewards {

    // ── State ──────────────────────────────────────────────────────────
    address public owner;
    bool    public paused;

    // Reward rates (in wei)
    uint256 public rewardPerRally = 10_000_000_000_000;   // 0.000010 ETH
    uint256 public rewardPerPoint = 100_000_000_000_000;  // 0.000100 ETH
    uint256 public rewardWinBonus = 500_000_000_000_000;  // 0.000500 ETH

    // Per-session cap (prevents runaway reward abuse in one game session)
    uint256 public sessionCap    = 5_000_000_000_000_000; // 0.005 ETH

    // Minimum seconds between consecutive claims from the same address
    uint256 public claimCooldown = 1 hours;

    // Accumulated unclaimed rewards per player
    mapping(address => uint256) public pendingReward;

    // Timestamp of last successful claim per player
    mapping(address => uint256) public lastClaim;

    // Trusted relayer / game server address allowed to call recordGame
    // (set to address(0) to allow owner only)
    address public relayer;

    // ── Events ─────────────────────────────────────────────────────────
    event Funded(address indexed funder, uint256 amount);
    event GameRecorded(address indexed player, uint256 rallies, uint256 points, bool won, uint256 reward);
    event RewardClaimed(address indexed player, uint256 amount);
    event RatesUpdated(uint256 perRally, uint256 perPoint, uint256 winBonus, uint256 cap);
    event RelayerUpdated(address indexed relayer);
    event Paused(bool isPaused);
    event Withdrawn(address indexed to, uint256 amount);

    // ── Modifiers ──────────────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(
            msg.sender == owner || (relayer != address(0) && msg.sender == relayer),
            "Not authorized"
        );
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Rewards paused");
        _;
    }

    // ── Constructor ────────────────────────────────────────────────────
    constructor() {
        owner = msg.sender;
    }

    // ── Funding ────────────────────────────────────────────────────────

    /// @notice Fund the contract with ETH to pay out as rewards.
    receive() external payable {
        emit Funded(msg.sender, msg.value);
    }

    /// @notice Explicit fund function (same as receive but more explicit).
    function fund() external payable {
        emit Funded(msg.sender, msg.value);
    }

    // ── Game logic ─────────────────────────────────────────────────────

    /**
     * @notice Record the outcome of a completed Pong game session and
     *         accrue rewards to the player's pending balance.
     * @param  player  The wallet address of the player.
     * @param  rallies Number of ball-paddle hits in the session.
     * @param  points  Number of points scored by this player.
     * @param  won     Whether this player won the match.
     */
    function recordGame(
        address player,
        uint32  rallies,
        uint32  points,
        bool    won
    ) external onlyAuthorized whenNotPaused {
        require(player != address(0), "Invalid player");
        require(points <= 11, "Invalid point count");

        uint256 reward = 0;
        reward += rallies * rewardPerRally;
        reward += points  * rewardPerPoint;
        if (won) {
            reward += rewardWinBonus;
        }

        // Cap per session
        if (reward > sessionCap) {
            reward = sessionCap;
        }

        // Ensure contract can cover it (soft cap — no revert, just zero out)
        if (reward > address(this).balance) {
            reward = 0;
        }

        if (reward > 0) {
            pendingReward[player] += reward;
            emit GameRecorded(player, rallies, points, won, reward);
        }
    }

    /**
     * @notice Convenience overload that accepts the scoring player address
     *         directly from the browser via ethers.js (msg.sender = player).
     *         The player supplies their own rally/point counts; the game
     *         applies the session cap to limit abuse.
     */
    function recordGameSelf(uint32 rallies, uint32 points, bool won)
        external
        whenNotPaused
    {
        this.recordGame(msg.sender, rallies, points, won);
    }

    // ── Claims ─────────────────────────────────────────────────────────

    /**
     * @notice Withdraw all accumulated rewards to the caller's wallet.
     *         Subject to a cooldown period between consecutive claims.
     */
    function claimRewards() external whenNotPaused {
        uint256 amount = pendingReward[msg.sender];
        require(amount > 0, "Nothing to claim");
        require(
            block.timestamp >= lastClaim[msg.sender] + claimCooldown,
            "Claim cooldown active"
        );
        require(address(this).balance >= amount, "Contract underfunded");

        pendingReward[msg.sender] = 0;
        lastClaim[msg.sender]     = block.timestamp;

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "Transfer failed");

        emit RewardClaimed(msg.sender, amount);
    }

    // ── View helpers ────────────────────────────────────────────────────

    /// @notice Seconds until the caller can claim again (0 if ready).
    function cooldownRemaining(address player) external view returns (uint256) {
        uint256 next = lastClaim[player] + claimCooldown;
        if (block.timestamp >= next) return 0;
        return next - block.timestamp;
    }

    /// @notice Total ETH held by this contract.
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ── Admin ───────────────────────────────────────────────────────────

    /// @notice Update reward rates and session cap (all values in wei).
    function setRates(
        uint256 _perRally,
        uint256 _perPoint,
        uint256 _winBonus,
        uint256 _sessionCap
    ) external onlyOwner {
        rewardPerRally = _perRally;
        rewardPerPoint = _perPoint;
        rewardWinBonus = _winBonus;
        sessionCap     = _sessionCap;
        emit RatesUpdated(_perRally, _perPoint, _winBonus, _sessionCap);
    }

    /// @notice Set or remove a trusted relayer address.
    function setRelayer(address _relayer) external onlyOwner {
        relayer = _relayer;
        emit RelayerUpdated(_relayer);
    }

    /// @notice Set the claim cooldown in seconds.
    function setClaimCooldown(uint256 seconds_) external onlyOwner {
        claimCooldown = seconds_;
    }

    /// @notice Pause / unpause reward accrual.
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit Paused(_paused);
    }

    /// @notice Emergency withdrawal of all contract ETH to the owner.
    function withdrawAll() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "Nothing to withdraw");
        (bool ok, ) = owner.call{value: bal}("");
        require(ok, "Transfer failed");
        emit Withdrawn(owner, bal);
    }

    /// @notice Transfer contract ownership.
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}
