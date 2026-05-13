using Microsoft.AspNetCore.Mvc;
using PatientPortalAPI.Core.Application.Interfaces;
using PatientPortalAPI.Core.Domain;

namespace PatientPortalAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ReferralsController(IReferralRepository referralRepository) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var referrals = await referralRepository.GetAllAsync();
        return Ok(referrals);
    }

    [HttpGet("pending")]
    public async Task<IActionResult> GetPending()
    {
        var referrals = await referralRepository.GetPendingReferralsAsync();
        return Ok(referrals);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var referral = await referralRepository.GetByIdAsync(id);
        if (referral == null) return NotFound();
        return Ok(referral);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Referral referral)
    {
        var id = await referralRepository.AddAsync(referral);
        referral.ReferralID = id;
        return CreatedAtAction(nameof(GetById), new { id = referral.ReferralID }, referral);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] Referral referral)
    {
        if (id != referral.ReferralID) return BadRequest();
        var updated = await referralRepository.UpdateAsync(referral);
        if (!updated) return NotFound();
        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var deleted = await referralRepository.DeleteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
