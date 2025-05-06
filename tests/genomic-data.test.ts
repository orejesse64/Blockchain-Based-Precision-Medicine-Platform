import { describe, it, expect, beforeEach } from 'vitest';

// Mock the Clarity contract environment
const mockTxSender = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const mockGenomicRecords = new Map();
const mockRecordsByPatient = new Map();

// Mock contract functions
const mockContract = {
  addGenomicRecord: (recordId, patientId, dataHash, dataLocation) => {
    if (mockGenomicRecords.has(recordId)) {
      return { type: 'err', value: 1 };
    }
    
    const currentTime = Date.now();
    mockGenomicRecords.set(recordId, {
      patientId,
      dataHash,
      dataLocation,
      timestamp: currentTime,
      authorizedViewers: [mockTxSender]
    });
    
    // Update records by patient
    const existingRecords = mockRecordsByPatient.get(patientId) || { records: [] };
    if (existingRecords.records.length >= 20) {
      return { type: 'err', value: 3 };
    }
    
    existingRecords.records.push(recordId);
    mockRecordsByPatient.set(patientId, existingRecords);
    
    return { type: 'ok', value: true };
  },
  
  authorizeViewer: (recordId, viewer) => {
    if (!mockGenomicRecords.has(recordId)) {
      return { type: 'err', value: 4 };
    }
    
    const record = mockGenomicRecords.get(recordId);
    if (record.authorizedViewers.length >= 10) {
      return { type: 'err', value: 3 };
    }
    
    if (!record.authorizedViewers.includes(viewer)) {
      record.authorizedViewers.push(viewer);
      mockGenomicRecords.set(recordId, record);
    }
    
    return { type: 'ok', value: true };
  },
  
  isAuthorized: (recordId, viewer) => {
    if (!mockGenomicRecords.has(recordId)) {
      return null;
    }
    
    const record = mockGenomicRecords.get(recordId);
    const index = record.authorizedViewers.indexOf(viewer);
    return index !== -1 ? index : null;
  },
  
  getGenomicRecord: (recordId) => {
    if (!mockGenomicRecords.has(recordId)) {
      return null;
    }
    
    const record = mockGenomicRecords.get(recordId);
    if (record.authorizedViewers.includes(mockTxSender)) {
      return record;
    }
    
    return null;
  },
  
  getPatientRecords: (patientId) => {
    return mockRecordsByPatient.get(patientId) || { records: [] };
  }
};

describe('Genomic Data Contract', () => {
  beforeEach(() => {
    // Clear mocks before each test
    mockGenomicRecords.clear();
    mockRecordsByPatient.clear();
  });
  
  it('should add a new genomic record', () => {
    const recordId = '123e4567-e89b-12d3-a456-426614174000';
    const patientId = '223e4567-e89b-12d3-a456-426614174001';
    const dataHash = new Uint8Array(32).fill(1); // Mock hash
    const dataLocation = 'ipfs://QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
    
    const result = mockContract.addGenomicRecord(
        recordId,
        patientId,
        dataHash,
        dataLocation
    );
    
    expect(result.type).toBe('ok');
    expect(result.value).toBe(true);
    
    const record = mockContract.getGenomicRecord(recordId);
    expect(record).not.toBeNull();
    expect(record.patientId).toBe(patientId);
    expect(record.dataLocation).toBe(dataLocation);
  });
  
  it('should not add a record with an existing ID', () => {
    const recordId = '123e4567-e89b-12d3-a456-426614174000';
    const patientId = '223e4567-e89b-12d3-a456-426614174001';
    const dataHash = new Uint8Array(32).fill(1);
    const dataLocation = 'ipfs://QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
    
    // Add first record
    mockContract.addGenomicRecord(
        recordId,
        patientId,
        dataHash,
        dataLocation
    );
    
    // Try to add another with the same ID
    const result = mockContract.addGenomicRecord(
        recordId,
        patientId,
        dataHash,
        dataLocation
    );
    
    expect(result.type).toBe('err');
    expect(result.value).toBe(1);
  });
  
  it('should authorize a new viewer', () => {
    const recordId = '123e4567-e89b-12d3-a456-426614174000';
    const patientId = '223e4567-e89b-12d3-a456-426614174001';
    const dataHash = new Uint8Array(32).fill(1);
    const dataLocation = 'ipfs://QmXoypizjW3WknFiJnKLwHCnL72vedxjQkDDP1mXWo6uco';
    const newViewer = 'ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    
    // Add record
    mockContract.addGenomicRecord(
        recordId,
        patientId,
        dataHash,
        dataLocation
    );
    
    // Authorize new viewer
    const result = mockContract.authorizeViewer(recordId, newViewer);
    
    expect(result.type).toBe('ok');
    expect(result.value).toBe(true);
    
    const isAuthorized = mockContract.isAuthorized(recordId, newViewer);
    expect(isAuthorized).not.toBeNull();
  });
  
  it('should track records by patient', () => {
    const patientId = '223e4567-e89b-12d3-a456-426614174001';
    
    // Add multiple records for the same patient
    mockContract.addGenomicRecord(
        '123e4567-e89b-12d3-a456-426614174000',
        patientId,
        new Uint8Array(32).fill(1),
        'ipfs://location1'
    );
    
    mockContract.addGenomicRecord(
        '223e4567-e89b-12d3-a456-426614174002',
        patientId,
        new Uint8Array(32).fill(2),
        'ipfs://location2'
    );
    
    const patientRecords = mockContract.getPatientRecords(patientId);
    expect(patientRecords.records.length).toBe(2);
    expect(patientRecords.records).toContain('123e4567-e89b-12d3-a456-426614174000');
    expect(patientRecords.records).toContain('223e4567-e89b-12d3-a456-426614174002');
  });
});
