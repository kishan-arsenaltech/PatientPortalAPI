using Microsoft.AspNetCore.Mvc;
using PatientPortalAPI.Core.Domain;
using PatientPortalAPI.Infrastructure.Data.Repositories;

namespace PatientPortalAPI.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class PatientsController(IPatientRepository patientRepository, ILogger<PatientsController> logger) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var patients = await patientRepository.GetAllAsync();
        return Ok(patients);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        var patient = await patientRepository.GetByIdAsync(id);
        if (patient == null) return NotFound();
        return Ok(patient);
    }

    [HttpGet("search")]
    public async Task<IActionResult> Search([FromQuery] string term)
    {
        if (string.IsNullOrWhiteSpace(term)) return BadRequest("Search term is required.");
        var results = await patientRepository.SearchByNameAsync(term);
        return Ok(results);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] Patient patient)
    {
        // In a real scenario, we would use a DTO and FluentValidation
        // For this phase, we map directly to the entity
        var id = await patientRepository.AddAsync(patient);
        patient.PatientID = id;
        return CreatedAtAction(nameof(GetById), new { id = patient.PatientID }, patient);
    }

    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update(Guid id, [FromBody] Patient patient)
    {
        if (id != patient.PatientID) return BadRequest("ID mismatch.");
        
        var updated = await patientRepository.UpdateAsync(patient);
        if (!updated) return NotFound();
        
        return NoContent();
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var deleted = await patientRepository.DeleteAsync(id);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
