using Microsoft.AspNetCore.Mvc;
using PatientPortalAPI.Core.Domain;
using PatientPortalAPI.Infrastructure.Data.Repositories;

namespace PatientPortalAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class ProvidersController(IProviderRepository providerRepository) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await providerRepository.GetAllAsync());

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var provider = await providerRepository.GetByIdAsync(id);
        return provider == null ? NotFound() : Ok(provider);
    }

    [HttpGet("npi/{npi}")]
    public async Task<IActionResult> GetByNpi(string npi)
    {
        var provider = await providerRepository.GetByNpiAsync(npi);
        return provider == null ? NotFound() : Ok(provider);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Provider provider)
    {
        var id = await providerRepository.AddAsync(provider);
        provider.ProviderID = id;
        return CreatedAtAction(nameof(GetById), new { id = provider.ProviderID }, provider);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] Provider provider)
    {
        if (id != provider.ProviderID) return BadRequest();
        return await providerRepository.UpdateAsync(provider) ? NoContent() : NotFound();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id) => await providerRepository.DeleteAsync(id) ? NoContent() : NotFound();
}
